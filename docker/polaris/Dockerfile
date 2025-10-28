FROM eclipse-temurin:21-jre-jammy

# Install dependencies
RUN apt-get update && \
    apt-get install -y curl postgresql-client && \
    rm -rf /var/lib/apt/lists/*

# Create polaris user
RUN groupadd -r polaris && useradd -r -g polaris polaris

# Set working directory
WORKDIR /app

# Download Polaris
ARG POLARIS_VERSION=1.1.0
RUN curl -L "https://github.com/apache/polaris/releases/download/v${POLARIS_VERSION}/polaris-service-${POLARIS_VERSION}.jar" \
    -o polaris-server.jar

# Copy configuration files
COPY polaris-server.yml /app/
COPY entrypoint.sh /app/

# Set permissions
RUN chown -R polaris:polaris /app && \
    chmod +x /app/entrypoint.sh

USER polaris

EXPOSE 8181

ENTRYPOINT ["/app/entrypoint.sh"]
