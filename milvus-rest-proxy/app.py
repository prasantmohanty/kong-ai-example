# app.py
from fastapi import FastAPI
from pydantic import BaseModel
from pymilvus import connections, Collection

app = FastAPI()

connections.connect("default", host="milvus-standalone", port="19530")

class SearchRequest(BaseModel):
    collection_name: str
    vector: list
    top_k: int

#@app.post("/search")
#def search(req: SearchRequest):
#    collection = Collection(req.collection_name)
#    res = collection.search([req.vector], "embedding", params={"metric_type": "L2"}, limit=req.top_k)
#    return {"results": [hit.to_dict() for hits in res for hit in hits]}


@app.post("/search")
def search(req: SearchRequest):
    collection = Collection(req.collection_name)
    search_params = {"metric_type": "COSINE", "params": {"nprobe": 10}}

    results = collection.search(
        data=[req.vector],
        anns_field="embedding",
        param=search_params,
        limit=req.top_k,
        output_fields=["text"]
    )

    hits = []
    for hit in results[0]:
        hits.append({"id": hit.id, "distance": hit.distance, "text": hit.entity.get("text")})

    return {"results": hits}
