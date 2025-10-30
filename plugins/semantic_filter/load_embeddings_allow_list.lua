local redis = require "redis"
local cjson = require "cjson"

-- Connect to Redis
local client = redis.connect('127.0.0.1', 6379)

-- Open the file
local file = io.open("allowlist.txt", "r")
if not file then
  error("Could not open allowlist.txt")
end

local index = 1
for line in file:lines() do
  local embedding = cjson.encode(cjson.decode(line)) -- ensure valid JSON
  local key = "prompt:allow:" .. index
  client:call("HSET", key, "embedding", embedding)
  index = index + 1
end

file:close()
