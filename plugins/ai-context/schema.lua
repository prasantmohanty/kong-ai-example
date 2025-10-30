local typedefs = require "kong.db.schema.typedefs"

return {
  name = "ai-context",
  fields = {
    { consumer = typedefs.no_consumer }, -- plugin cannot be configured per consumer
    { protocols = typedefs.protocols_http }, -- only works on HTTP/HTTPS
    { config = {
        type = "record",
        fields = {
          { enabled = { type = "boolean", default = true } },
          { context_key = { type = "string", default = "ai_context" } }
        }
      }
    }
  }
}
