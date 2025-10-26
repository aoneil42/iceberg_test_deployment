FROM apache/polaris:1.1.0-incubating

# The official Apache Polaris image supports both amd64 and arm64
# Environment variables for Polaris configuration
ENV POLARIS_BOOTSTRAP_REALM=default-realm
ENV POLARIS_BOOTSTRAP_CLIENT_ID=polaris-admin
ENV POLARIS_BOOTSTRAP_CLIENT_SECRET=polaris-secret-123
ENV CATALOG_STORE_TYPE=in-memory

# Expose Polaris ports
EXPOSE 8181 8182

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8182/healthcheck || exit 1