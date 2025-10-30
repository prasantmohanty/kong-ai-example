local typedefs = require "kong.db.schema.typedefs"

return {
  name = "token_quotai_validator",
  fields = {
    { consumer = typedefs.no_consumer },
    { protocols = typedefs.protocols_http },
    { config = {
        type = "record",
        fields = {
	  { redis_host = { type = "string", default = "127.0.0.1" } },
          { redis_port = { type = "number", default = 6379 } },
          { user_id_header = { type = "string", default = "X-User-ID" } },
          { default_max_tokens = { type = "number", default = 1000} }
        }
      }
    }
  }
}
