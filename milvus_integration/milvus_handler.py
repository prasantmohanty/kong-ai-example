from pymilvus import connections, Collection, FieldSchema, CollectionSchema, DataType,utility
import requests
import os


connections.connect("default", host="localhost", port="19530")

# Drop the existing collection
collection_name = "conversation_memory"
if utility.has_collection(collection_name):
    utility.drop_collection(collection_name)
    print(f"Collection '{collection_name}' has been dropped successfully.")
else:
    print(f"Collection '{collection_name}' does not exist.")

fields = [
    FieldSchema(name="session_id", dtype=DataType.VARCHAR, max_length=64,is_primary=True),
    FieldSchema(name="text", dtype=DataType.VARCHAR, max_length=1024),
    FieldSchema(name="embedding", dtype=DataType.FLOAT_VECTOR, dim=4096)
]
schema = CollectionSchema(fields, description="Conversation memory")
collection = Collection("conversation_memory", schema=schema)

collection.create_index(field_name="embedding", index_params={"index_type": "IVF_FLAT", "metric_type": "COSINE", "params": {"nlist": 128}})

def generate_embedding(text):  
    url = os.getenv("OLLAMA_EMBEDDING_URL", "http://localhost:11434/api/embeddings") 
    payload = {
        "model": "finetuned_mistral:latest",
        "prompt": text
    }

    proxies = {
        "http": None,
        "https": None
    }


    # Send the POST request to Ollama embedding API
    response = requests.post(url, json=payload, proxies=proxies)

    # Raise an exception if the request failed
    response.raise_for_status()

    # Return the embedding from the response
    return response.json()["embedding"]


def store_message(session_id, text):
    embedding = generate_embedding(text)
    collection.insert([[session_id], [text], [embedding]])
    collection.flush()

def retrieve_context(user_input, top_k=5):
    embedding = generate_embedding(user_input)
    search_params = {"metric_type": "COSINE", "params": {"nprobe": 10}}
    results = collection.search([embedding], "embedding", param=search_params, limit=top_k)
    context = "\n".join([hit.entity.get("text") for hit in results[0]])
    return context
