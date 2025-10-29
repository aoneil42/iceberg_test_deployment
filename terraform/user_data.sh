#!/bin/bash
set -e

# Update system
yum update -y

# Install Docker
yum install -y docker
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install PostgreSQL client for health checks
amazon-linux-extras enable postgresql14
yum install -y postgresql

# Create deployment directory
mkdir -p /home/ec2-user/deployment
cd /home/ec2-user/deployment

# Create docker-compose.yml
cat > docker-compose.yml <<'EOF'
version: '3.8'

services:
  polaris:
    image: ${ecr_registry}/polaris:latest
    container_name: polaris-catalog
    ports:
      - "8181:8181"
    environment:
      # PostgreSQL configuration
      POLARIS_METASTORE_TYPE: postgres
      POSTGRES_HOST: ${db_host}
      POSTGRES_PORT: ${db_port}
      POSTGRES_DB: ${db_name}
      POSTGRES_USER: ${db_username}
      POSTGRES_PASSWORD: ${db_password}
      
      # Polaris configuration
      POLARIS_CLIENT_ID: ${polaris_client_id}
      POLARIS_CLIENT_SECRET: ${polaris_client_secret}
      
      # AWS S3 configuration
      AWS_REGION: ${aws_region}
      S3_WAREHOUSE_BUCKET: ${s3_warehouse_bucket}
      
      # Java options for memory
      JAVA_OPTS: "-Xmx2g -Xms1g"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8181/v1/config"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 60s
    restart: unless-stopped
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  ogc-api:
    image: ${ecr_registry}/ogc-api:latest
    container_name: ogc-api-features
    ports:
      - "8080:8080"
    environment:
      # Polaris connection
      POLARIS_ENDPOINT: http://polaris:8181
      POLARIS_CLIENT_ID: ${polaris_client_id}
      POLARIS_CLIENT_SECRET: ${polaris_client_secret}
      
      # AWS S3 configuration
      AWS_REGION: ${aws_region}
      S3_WAREHOUSE_BUCKET: ${s3_warehouse_bucket}
      
      # OGC API configuration
      OGC_API_TITLE: "Geospatial Features API"
      OGC_API_DESCRIPTION: "OGC API Features service powered by Apache Iceberg"
      SERVER_HOST: "0.0.0.0"
      SERVER_PORT: "8080"
      
      # DuckDB configuration
      DUCKDB_MEMORY_LIMIT: "1GB"
      DUCKDB_THREADS: "2"
    depends_on:
      polaris:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 30s
    restart: unless-stopped
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

networks:
  default:
    name: geospatial-network

EOF

# Wait for RDS to be available
echo "Waiting for RDS PostgreSQL to be available..."
until PGPASSWORD="${db_password}" psql -h "${db_host}" -U "${db_username}" -d "${db_name}" -c '\q' 2>/dev/null; do
  echo "Waiting for PostgreSQL... (this may take 2-3 minutes)"
  sleep 10
done
echo "✅ PostgreSQL is available!"

# Initialize Polaris schema in PostgreSQL (if needed)
# The Polaris container will handle schema initialization on first run

# Login to ECR
aws ecr get-login-password --region ${aws_region} | docker login --username AWS --password-stdin ${ecr_registry}

# Pull latest images
docker-compose pull

# Start services
docker-compose up -d

# Wait for services to be healthy
echo "Waiting for services to be healthy..."
sleep 30

# Check Polaris health
for i in {1..30}; do
  if curl -sf http://localhost:8181/v1/config > /dev/null 2>&1; then
    echo "✅ Polaris is healthy!"
    break
  fi
  echo "Waiting for Polaris... ($i/30)"
  sleep 10
done

# Check OGC API health
for i in {1..30}; do
  if curl -sf http://localhost:8080/ > /dev/null 2>&1; then
    echo "✅ OGC API is healthy!"
    break
  fi
  echo "Waiting for OGC API... ($i/30)"
  sleep 10
done

# Create default namespace and catalog in Polaris (if first run)
echo "Initializing Polaris catalogs..."
cat > /tmp/init_polaris.sh <<'INIT_EOF'
#!/bin/bash
# This will be run after Polaris is fully started

# Create default namespace
curl -X POST http://localhost:8181/v1/polaris/namespaces \
  -H "Content-Type: application/json" \
  -d '{
    "namespace": "default",
    "properties": {
      "description": "Default namespace for geospatial data"
    }
  }' || true

echo "Polaris initialization complete!"
INIT_EOF

chmod +x /tmp/init_polaris.sh
/tmp/init_polaris.sh

# Set ownership
chown -R ec2-user:ec2-user /home/ec2-user/deployment

# Create systemd service for auto-restart
cat > /etc/systemd/system/geospatial-platform.service <<'SERVICE_EOF'
[Unit]
Description=Geospatial Platform Docker Compose
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/home/ec2-user/deployment
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
TimeoutStartSec=300

[Install]
WantedBy=multi-user.target
SERVICE_EOF

# Enable the service
systemctl daemon-reload
systemctl enable geospatial-platform.service

echo "Deployment complete!"
echo "Polaris: http://localhost:8181/v1/config"
echo "OGC API: http://localhost:8080/"