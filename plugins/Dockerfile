FROM kong/kong-gateway:3.11.0.3

USER root

# Create plugin directory
RUN mkdir -p /usr/local/share/lua/5.1/kong/plugins/semantic_filter
RUN mkdir -p /usr/local/share/lua/5.1/kong/plugins/token_quota_validator
RUN mkdir -p /usr/local/share/lua/5.1/kong/plugins/common_config
RUN mkdir -p /usr/local/share/lua/5.1/kong/plugins/ai-context

# Copy plugin files
COPY semantic_filter/handler.lua /usr/local/share/lua/5.1/kong/plugins/semantic_filter/handler.lua
COPY semantic_filter/schema.lua /usr/local/share/lua/5.1/kong/plugins/semantic_filter/schema.lua

COPY ai-context/handler.lua /usr/local/share/lua/5.1/kong/plugins/ai-context/handler.lua
COPY ai-context/schema.lua /usr/local/share/lua/5.1/kong/plugins/ai-context/schema.lua

COPY token_quota_validator/handler.lua /usr/local/share/lua/5.1/kong/plugins/token_quota_validator/handler.lua
COPY token_quota_validator/schema.lua /usr/local/share/lua/5.1/kong/plugins/token_quota_validator/schema.lua

COPY common_config/init.lua /usr/local/share/lua/5.1/kong/plugins/common_config/init.lua

# Set plugin environment
ENV KONG_PLUGINS=bundled,token_quota_validator,semantic_filter,common_config,ai-context

USER kong

