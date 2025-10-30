local redis = require "resty.redis"
local http = require "resty.http"
local cjson = require "cjson.safe"
local common_config = require "kong.plugins.common_config"

local SemanticFilterHandler = {
  VERSION = "1.1.0",
  PRIORITY = 1000,
}

--function SemanticFilterHandler.body_filter(conf)
--  local chunk = kong.response.get_raw_body()
--  local user_id = kong.request.get_header(conf.user_id_header or common_config.user_id_header)
--  if not chunk or not user_id then return end
--  kong.log.notice("[semantic_filter] using the body filter for response for ", user_id )
--  common_config.track_response_tokens(conf, chunk, user_id)
--end


-- Aggregate response chunks in body_filter

--function SemanticFilterHandler:body_filter(conf)
--  local chunk = kong.response.get_raw_body()
--  if chunk and #chunk > 0 then
--    ngx.ctx.last_chunk = chunk
--  end
--end

--function SemanticFilterHandler:body_filter(conf)
--  local chunk = kong.response.get_raw_body()
--  if not chunk or #chunk == 0 then return end

--  local ok, decoded = pcall(cjson.decode, chunk)
--  kong.log.inspect(decoded)
--  if ok and decoded and decoded.done then
--    ngx.ctx.final_chunk = chunk
--    kong.log.notice("chunk ",chunk)
--  end
--end


function SemanticFilterHandler:body_filter(conf)
  local chunk = kong.response.get_raw_body()
  if chunk and #chunk > 0 then
    ngx.ctx.chunks = ngx.ctx.chunks or {}
    table.insert(ngx.ctx.chunks, chunk)
  end
end

function SemanticFilterHandler:log(conf)
  local chunks = ngx.ctx.chunks
  if not chunks or #chunks == 0 then
    kong.log.err("[semantic_filter] No chunks found")
    return
  end

  -- Combine all chunks into one string
  local combined = table.concat(chunks)
  kong.log.notice("combined : " , combined) 

  -- Split by newline
  for line in combined:gmatch("[^\n]+") do
    kong.log.notice("line : " , line)  
    local ok, decoded = pcall(cjson.decode, line)
     kong.log.notice("decoded : " , decoded)
    if ok and decoded and decoded.done then
      -- Found final chunk
      local prompt_tokens = decoded.prompt_eval_count or 0
      local completion_tokens = decoded.eval_count or 0
      local total_tokens = prompt_tokens + completion_tokens

      if decoded.usage then
        total_tokens = decoded.usage.total_tokens or total_tokens
      end

      kong.log.notice("[semantic_filter] Final chunk found. prompt_tokens:", prompt_tokens,
                      " completion_tokens:", completion_tokens,
                      " total_tokens:", total_tokens)

      local user_id = kong.request.get_header(conf.user_id_header or common_config.user_id_header)
      if user_id and total_tokens > 0 then
        common_config.track_response_tokens(conf, total_tokens, user_id)
      end
      return
    end
  end

  kong.log.err("[semantic_filter] No final chunk with done=true found")
end

--[[function SemanticFilterHandler:log(conf)
  local chunks = ngx.ctx.chunks
  if not chunks or #chunks == 0 then
    kong.log.err("[semantic_filter] No chunks found")
    return
  end

    -- Combine all chunks into one string
  local combined = table.concat(chunks)


  -- Find the last chunk with done=true
  local final_chunk
  for _, chunk in ipairs(chunks) do
    kong.log.inspect("chunk loop",chunk)
  end 
  for _, chunk in ipairs(chunks) do
    local ok, decoded = pcall(cjson.decode, chunk)
    kong.log.inspect("decoded loop",decoded)
    if ok and decoded and decoded.done then
      final_chunk = decoded
    end
  end

  if not final_chunk then
    kong.log.err("[semantic_filter] No final chunk with done=true found")
    return
  end

--  if not response.done then
--    kong.log.notice("[semantic_filter] Last chunk is not final, skipping")
--    return
--  end



  -- Handle Ollama-style fields
  local prompt_tokens = final_chunk.prompt_eval_count or 0
  local completion_tokens = final_chunk.eval_count or 0
  local total_tokens = prompt_tokens + completion_tokens

  -- Handle OpenAI-style usage if present
  if final_chunk.usage then
    total_tokens = final_chunk.usage.total_tokens or total_tokens
  end

  kong.log.notice("[semantic_filter] prompt_tokens:", prompt_tokens,
                  " completion_tokens:", completion_tokens,
                  " total_tokens:", total_tokens)

  -- Track tokens in Redis via common_config
  local user_id = kong.request.get_header(conf.user_id_header or common_config.user_id_header)
  if user_id and total_tokens > 0 then
    common_config.track_response_tokens(conf, total_tokens, user_id)
  end
end
]]--

-- Cosine similarity function
local function cosine_similarity(vec1, vec2)
  kong.log.notice("[semantic_filter] inside cosine_similarity running ")
  if #vec1 ~= #vec2 then return 0 end
  local dot, norm1, norm2 = 0, 0, 0
  for i = 1, #vec1 do
    dot = dot + vec1[i] * vec2[i]
    norm1 = norm1 + vec1[i]^2
    norm2 = norm2 + vec2[i]^2
  end
  if norm1 == 0 or norm2 == 0 then return 0 end
  return dot / (math.sqrt(norm1) * math.sqrt(norm2))
end

function SemanticFilterHandler:access(conf)
  kong.log.notice("[semantic_filter] running")
  kong.log.inspect(conf)  -- Debug: check if config is passed correctly
  local body_raw = kong.request.get_raw_body()
  local body_json = cjson.decode(body_raw)
  local prompt = body_json and body_json.prompt or ""
  
  kong.log.notice("[semantic_filter] prompt: ", prompt)

  if prompt == "" then
    return kong.response.exit(400, { message = "Missing prompt in request body." })
  end

  -- Step 1: Get embedding from Ollama
  kong.log.notice("model used: " , conf.embedding_model)
  local httpc = http.new()
  local res, err = httpc:request_uri(conf.embedding_endpoint, {
    method = "POST",
    body = cjson.encode({ model = conf.embedding_model, prompt = prompt }),
    headers = { ["Content-Type"] = "application/json" },
  })

  if not res or res.status ~= 200 then
    kong.log.err("[semantic_filter] Failed to get embedding: ", err or res.body)
    return kong.response.exit(500, { message = "Embedding service error." })
  end

  local embedding_response = cjson.decode(res.body)
  local input_embedding = embedding_response and embedding_response.embedding
  if not input_embedding then
    return kong.response.exit(500, { message = "Invalid embedding response." })
  end

  -- Step 2: Connect to Redis
  local red = redis:new()
  red:set_timeout(1000)
  local ok, err = red:connect(conf.redis_host or "127.0.0.1", conf.redis_port or 6379)
  if not ok then
    kong.log.err("Failed to connect to Redis: ", err)
    return kong.response.exit(500, { message = "Redis connection error." })
  end

  -- Step 3: Scan Redis for deny embeddings
  local cursor = "0"
  local threshold = conf.similarity_threshold or 0.85
  local match_found = false

  repeat
    local res, scan_err = red:scan(cursor, "MATCH", "prompt:deny:*", "COUNT", 100)
    kong.log.inspect(res)
    if not res then break end
    cursor = res[1]
    for _, key in ipairs(res[2]) do
      --local value = red:get(key)
      local value = red:hget(key, "embedding")
      kong.log.inspect(value)
      if value and value ~= ngx.null then
        local decoded = cjson.decode(value)
        local deny_embedding = decoded and decoded.embedding
	kong.log.inspect(deny_embedding)
        if deny_embedding then
          local similarity = cosine_similarity(input_embedding, deny_embedding)
          kong.log.debug("[semantic_filter] Similarity with ", key, ": ", similarity)
          if similarity >= threshold then
            match_found = true
            break
          end
        end
      end
    end
  until cursor == "0" or match_found
    
  kong.log.inspect(match_found)
  if match_found then
    return kong.response.exit(403, { message = "[semantic_filter] Prompt blocked by Redis deny list (semantic match)." })
  end
end

return SemanticFilterHandler
