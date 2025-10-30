local redis = require "resty.redis"
local _M = {}


function _M.track_response_tokens(conf, total_tokens, user_id)
  kong.log.notice("[common config track_response_tokens ] running  " )

  if total_tokens == 0 then return end

--OpenAI specific token counts 
--  local total_tokens = response.usage.total_tokens or 0
--  kong.log.notice("[common config track_response_tokens ] total_tokens :" ,total_tokens  )
--  if total_tokens == 0 then return end

ngx.timer.at(0, function()
  local red = redis:new()
  red:set_timeout(1000)

  local ok, err = red:connect(conf.redis_host or _M.redis_host, conf.redis_port or _M.redis_port)
  if not ok then
    kong.log.err("Redis connection failed in common_config: ", err)
    return
  end
  kong.log.notice("[common config track_response_tokens ] updating token count for  ", user_id," with total token ", total_tokens )

  local usage_key = "token_usage:" .. user_id
  red:incrby(usage_key, total_tokens)
  red:expire(usage_key, 2592000)
  red:set_keepalive(10000, 100)
  kong.log.notice("[common config track_response_tokens ] token count update completed" )
 end)
end

-- Shared defaults
_M.redis_host = "redis-redis-stack-1"
_M.redis_port = 6379
_M.default_max_tokens = 400
_M.user_id_header = "X-User-ID"


return _M
