local http = require "resty.http"
local json = require "cjson"
local cjson = require "cjson.safe"


local AiContextHandler = {
  PRIORITY = 1200,
  VERSION = "1.0.0",
}

local milvus_url = "http://milvus-rest-proxy:8001/search"
local embedding_api = "http://ollama:11434/api/embeddings"
local top_k = 5
local embedding_model = "finetuned_mistral:latest"

local function retrieve_context(user_input)
    kong.log.notice("-----inside retrive context----")	
    local httpc = http.new()
    -- Generate embedding
    local res, err = httpc:request_uri(embedding_api, {
        method = "POST",
	body = json.encode({ model = embedding_model, prompt = user_input }),
        headers = { ["Content-Type"] = "application/json" },
    })

   -- kong.log.inspect(res) 	
    if not res then return nil end
    local embedding = json.decode(res.body).embedding
    --kong.log.inspect(embedding)
    -- Query Milvus
    local query_body = {
        collection_name = "conversation_memory",
        vector = embedding,
        top_k = top_k
    }


    local res, err = httpc:request_uri(milvus_url, {
        method = "POST",
        body = cjson.encode(query_body),
        headers = { ["Content-Type"] = "application/json" },
        keepalive = false
    })

    if not res then
        kong.log.err("Failed to call Milvus proxy: ", err)
        return nil, "Milvus proxy request failed"
    end

    if res.status ~= 200 then
        kong.log.err("Milvus proxy returned status: ", res.status, " body: ", res.body)
        return nil, "Milvus proxy error: " .. res.status
    end

    local decoded, decode_err = cjson.decode(res.body)
    if not decoded then
        kong.log.err("Failed to decode Milvus response: ", decode_err)
        return nil, "Invalid JSON from Milvus proxy"
    end

    -- Extract results
    local results = decoded.results or {}
    kong.log.notice("Retrieved context from Milvus: ", cjson.encode(results))
    return results




-------------
 --local milvus_res, milvus_err = httpc:request_uri(milvus_url .. "/search", {
 --       method = "POST",
 --       body = json.encode(query_body),
 --       headers = { ["Content-Type"] = "application/json" }
 --   })

 --   kong.log.inspect(milvus_res)

 --   if not milvus_res then return nil end
 --   local context_results = json.decode(milvus_res.body).results

--    local context = ""
--    for _, item in ipairs(_results) do
--        context = context .. item.text .. "\n"
--    end
--    kong.log.inspect(context)
--    return context
end

local function format_context(context_table)
    kong.log.notice("----running format_context")
    if type(context_table) ~= "table" then
        return ""
    end

    local parts = {}
    for _, item in ipairs(context_table) do
        if type(item) == "table" and item.text then
            table.insert(parts, item.text)
        end
    end
    kong.log.inspect(parts)
    return table.concat(parts, "\n")
end

function AiContextHandler:access(conf)

    ngx.req.read_body()  -- Important: read the body first
    local user_input = ngx.req.get_body_data()
    local decoded_body = cjson.decode(user_input)
    local user_text = decoded_body.prompt or ""  -- Extract only the text

      if not user_text then
          kong.log.warn("No body data found")
      return
      end 
      kong.log.inspect(user_text)

    local context = retrieve_context(user_text)
    if context and #context > 0 then
        local context_str = format_context(context)
        local enriched_prompt = "Context:\n" .. context_str .. "\nUser:\n" .. user_text
	
	--body for LLM
	local new_body = cjson.encode({ model="finetuned_mistral:latest",
					prompt = enriched_prompt 
    					--stream = false
				})
	kong.log.inspect(new_body)
	ngx.req.set_body_data(new_body)
	ngx.req.set_header("Content-Type", "application/json")
	kong.log.inspect(ngx.req)

    end
end

return AiContextHandler
