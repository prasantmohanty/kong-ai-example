import redis
import json

# Connect to Redis
r = redis.Redis(host='localhost', port=6379, decode_responses=True)

# Read embeddings from file
with open('denylist.txt', 'r') as f:
    lines = f.readlines()

# Load each embedding into Redis
for idx, line in enumerate(lines, start=1):
    try:
        embedding = json.loads(line.strip())
        key = f"prompt:deny:{idx}"
        r.hset(key, mapping={"embedding": json.dumps(embedding)})
        print(f"Stored {key}")
    except json.JSONDecodeError:
        print(f"Invalid JSON on line {idx}")
