FROM eclipse-temurin:21-jre-jammy

# Set working directory
WORKDIR /app

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl=7.* \
    wget=1.* \
    && rm -rf /var/lib/apt/lists/*

# Download Apache Polaris
ARG POLARIS_VERSION=0.1.0
RUN wget -nv https://github.com/polaris-catalog/polaris/releases/download/v${POLARIS_VERSION}/polaris-server.jar

# Copy config files
COPY polaris-server.yml /app/conf/polaris-server.yml
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Expose Polaris port
EXPOSE 8181

# Set environment variables
ENV JAVA_OPTS="-Xmx1g -Xms512m"
ENV POLARIS_CONFIG=/app/conf/polaris-server.yml

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8181/v1/config || exit 1

# Run Polaris
ENTRYPOINT ["/app/entrypoint.sh"]