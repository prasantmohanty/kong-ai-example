local typedefs = require "kong.db.schema.typedefs"

return {
  name = "semantic_filter",
  fields = {
    { consumer = typedefs.no_consumer },
    { protocols = typedefs.protocols_http },
    { config = {
        type = "record",
        fields = {
          { prompt_guard = { type = "string", required = true } },
          { redis_host = { type = "string", default = "127.0.0.1" } },
          { redis_port = { type = "number", default = 6379 } },
	  { embedding_endpoint = { type = "string", required = true } },
	  { embedding_model = { type = "string", default="finetuned_mistral:latest" } },
	  { similarity_threshold = { type = "number", default = 0.85 } },
        },
      },
    },
  },
}
