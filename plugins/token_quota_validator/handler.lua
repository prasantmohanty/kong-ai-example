local redis = require "resty.redis"
local common_config = require "kong.plugins.common_config"


local TokenQuotaValidatorHandler = {
  PRIORITY = 1100,
  VERSION = "1.0.0",
}


-- Aggregate response chunks in body_filter
--function TokenQuotaValidatorHandler:body_filter(conf)
--  local chunk = kong.response.get_raw_body()
--  if not chunk then return end
--  ngx.ctx.buffered_response = (ngx.ctx.buffered_response or "") .. chunk
--end



--function TokenQuotaValidatorHandler.body_filter(conf)
--local chunk = kong.response.get_raw_body()
--  local user_id = kong.request.get_header(conf.user_id_header or common_config.user_id_header)
--  if not chunk or not user_id then return end
--  kong.log.notice("[TokenQuotaValidatorHandler body filter] response token count for ", user_id)
--  common_config.track_response_tokens(conf, chunk, user_id)
--end




-- Estimate tokens based on prompt length
local function estimate_tokens(prompt)
  if not prompt then return 0 end
  return math.floor(#prompt / 4)
end

function TokenQuotaValidatorHandler.access(conf)

   local redis_host = conf.redis_host or common_config.redis_host
  local redis_port = conf.redis_port or common_config.redis_port
  local user_id_header = conf.user_id_header or common_config.user_id_header
  local default_max_tokens = conf.default_max_tokens or common_config.default_max_tokens

  kong.log.inspect(conf)  -- Debug: check if config is passed correctly
  kong.log.inspect(common_config)

  local header_name = user_id_header
  if type(header_name) ~= "string" then
    return kong.response.exit(500, { message = "Invalid header name configuration" })
  end

  local user_id = kong.request.get_header(header_name)
  if not user_id then
    return kong.response.exit(400, { message = "Missing user ID header" })
  end

  local body, err = kong.request.get_body()
  if not body or not body["prompt"] then
    return kong.response.exit(400, { message = "Missing prompt in request body" })
  end

  local prompt = body["prompt"]
  local token_count = estimate_tokens(prompt)

  local red = redis:new()
  red:set_timeout(1000)
  

  local ok, err = red:connect( redis_host ,redis_port )
  if not ok then
    return kong.response.exit(500, { message = "Redis connection failed: " .. err })
  end

  local max_tokens_key = "max_tokens:" .. user_id
  local max_tokens = tonumber(red:get(max_tokens_key))
  if not max_tokens then
    max_tokens = default_max_tokens
  end
  kong.log.inspect(max_tokens)

  local usage_key = "token_usage:" .. user_id
  local current_usage = tonumber(red:get(usage_key)) or 0

  kong.log.inspect(current_usage)

  if current_usage + token_count > max_tokens then
    return kong.response.exit(429, { message = "Token quota exceeded" })
  end

  red:incrby(usage_key, token_count)
  red:expire(usage_key, 2592000)

  red:set_keepalive(10000, 100)
  kong.log.notice("token count",token_count)

end

return TokenQuotaValidatorHandler
