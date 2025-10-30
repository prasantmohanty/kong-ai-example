FROM kong/kong-gateway:3.11.0.3

USER root

# Create plugin directory
RUN mkdir -p /usr/local/share/lua/5.1/kong/plugins/semantic_filter

# Copy plugin files
COPY handler.lua /usr/local/share/lua/5.1/kong/plugins/semantic_filter/handler.lua
COPY schema.lua /usr/local/share/lua/5.1/kong/plugins/semantic_filter/schema.lua

# Set plugin environment
ENV KONG_PLUGINS=bundled,semantic_filter

USER kong
