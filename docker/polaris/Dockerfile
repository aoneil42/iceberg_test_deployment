FROM apache/polaris:1.1.0-incubating

# Polaris requires bootstrapping on first run
# The official image needs environment variables set
ENV POLARIS_BOOTSTRAP=true
ENV POLARIS_PERSISTENCE_TYPE=in-memory

# For production, you'd use:
# ENV POLARIS_PERSISTENCE_TYPE=metastore
# ENV AWS_REGION=us-west-2

# Expose Polaris ports
# 8181 - Main API
# 8182 - Management/Health
EXPOSE 8181 8182

# Use the correct health check endpoint
HEALTHCHECK --interval=30s --timeout=10s --start-period=90s --retries=5 \
    CMD curl -f http://localhost:8181/api/catalog/v1/config || exit 1