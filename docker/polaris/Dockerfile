FROM apache/polaris:1.1.0-incubating

# Expose Polaris ports
# 8181 - Polaris service endpoint
# 8182 - Health/metrics endpoint
EXPOSE 8181 8182

# The official image already has:
# - Java runtime
# - Polaris application
# - Default configuration
# - Entrypoint configured

# Optional: Copy custom configuration if you have one
# COPY polaris-server.yml /app/conf/polaris-server.yml

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8182/healthcheck || exit 1