#!/bin/bash
set -e

# Log everything to both console and file
exec > >(tee -a /var/log/user-data.log)
exec 2>&1

echo "=== Starting user data script at $(date) ==="

# Update system
yum update -y

# Install required packages
yum install -y docker git postgresql15
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

# Install Session Manager plugin
yum install -y amazon-ssm-agent
systemctl start amazon-ssm-agent
systemctl enable amazon-ssm-agent

# Get instance metadata
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

echo "Region: $REGION"
echo "Instance ID: $INSTANCE_ID"
echo "Public IP: $PUBLIC_IP"

# Wait for RDS to be available
echo "Checking RDS status..."
RDS_INSTANCE_ID="${rds_instance_id}"
RDS_STATE=$(aws rds describe-db-instances \
  --db-instance-identifier $RDS_INSTANCE_ID \
  --region $REGION \
  --query 'DBInstances[0].DBInstanceStatus' \
  --output text 2>/dev/null || echo "unknown")

echo "RDS state: $RDS_STATE"

if [ "$RDS_STATE" = "stopped" ]; then
  echo "RDS is stopped. Starting it now..."
  aws rds start-db-instance \
    --db-instance-identifier $RDS_INSTANCE_ID \
    --region $REGION
  
  echo "Waiting for RDS to become available (this may take 5-10 minutes)..."
  aws rds wait db-instance-available \
    --db-instance-identifier $RDS_INSTANCE_ID \
    --region $REGION \
    --cli-read-timeout 0 \
    --cli-connect-timeout 60
  
  echo "RDS is now available"
elif [ "$RDS_STATE" = "available" ]; then
  echo "RDS is already available"
else
  echo "RDS state: $RDS_STATE - waiting for it to become available..."
  aws rds wait db-instance-available \
    --db-instance-identifier $RDS_INSTANCE_ID \
    --region $REGION \
    --cli-read-timeout 0 \
    --cli-connect-timeout 60
fi

# Get RDS endpoint (refresh after potential start)
RDS_ENDPOINT=$(aws rds describe-db-instances \
  --db-instance-identifier $RDS_INSTANCE_ID \
  --region $REGION \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text)

RDS_PORT=$(aws rds describe-db-instances \
  --db-instance-identifier $RDS_INSTANCE_ID \
  --region $REGION \
  --query 'DBInstances[0].Endpoint.Port' \
  --output text)

echo "RDS Endpoint: $RDS_ENDPOINT:$RDS_PORT"

# Test PostgreSQL connection
echo "Testing PostgreSQL connection..."
export PGPASSWORD="${db_password}"
for i in {1..30}; do
  if psql -h $RDS_ENDPOINT -p $RDS_PORT -U ${db_username} -d ${db_name} -c "SELECT version();" > /dev/null 2>&1; then
    echo "PostgreSQL connection successful!"
    break
  fi
  echo "Attempt $i/30 - Waiting for PostgreSQL to be ready..."
  sleep 5
done

# Initialize PostgreSQL schema for Polaris
echo "Initializing PostgreSQL schema for Polaris..."
psql -h $RDS_ENDPOINT -p $RDS_PORT -U ${db_username} -d ${db_name} << 'SQL'
-- Create Polaris schema if it doesn't exist
CREATE SCHEMA IF NOT EXISTS polaris;

-- Grant permissions
GRANT ALL ON SCHEMA polaris TO ${db_username};

-- Create initial tables for Polaris (Quarkus/Hibernate will manage the rest)
SET search_path TO polaris;
SQL

echo "PostgreSQL initialization complete"

# Create deployment directory
mkdir -p /home/ec2-user/deployment
cd /home/ec2-user/deployment

# Create .env file with PostgreSQL configuration
cat > .env << 'ENVEOF'
# AWS Configuration
AWS_REGION=${aws_region}
AWS_DEFAULT_REGION=${aws_region}

# RDS PostgreSQL Configuration
DB_HOST=$RDS_ENDPOINT
DB_PORT=$RDS_PORT
DB_NAME=${db_name}
DB_USERNAME=${db_username}
DB_PASSWORD=${db_password}
DB_JDBC_URL=jdbc:postgresql://$RDS_ENDPOINT:$RDS_PORT/${db_name}

# Polaris Configuration
CLIENT_ID=root
CLIENT_SECRET=${client_secret}
POLARIS_REALM=${polaris_realm}

# S3 Configuration
S3_BUCKET=${s3_bucket}
S3_WAREHOUSE_BUCKET=${s3_warehouse_bucket}
WAREHOUSE_BUCKET=${s3_warehouse_bucket}

# ECR Configuration
ECR_REGISTRY=${ecr_registry}
POLARIS_IMAGE=${ecr_polaris_image}
OGC_API_IMAGE=${ecr_ogc_api_image}
ENVEOF

# Substitute the RDS endpoint variables
sed -i "s/\$RDS_ENDPOINT/$RDS_ENDPOINT/g" .env
sed -i "s/\$RDS_PORT/$RDS_PORT/g" .env

# Create docker-compose.yml with PostgreSQL configuration
cat > docker-compose.yml << 'COMPOSEEOF'
version: '3.8'

services:
  polaris-catalog:
    image: ${ecr_polaris_image}
    container_name: polaris-catalog
    environment:
      # PostgreSQL Configuration for Polaris (using Quarkus properties)
      QUARKUS_DATASOURCE_JDBC_URL: jdbc:postgresql://$RDS_ENDPOINT:$RDS_PORT/${db_name}
      QUARKUS_DATASOURCE_USERNAME: ${db_username}
      QUARKUS_DATASOURCE_PASSWORD: ${db_password}
      QUARKUS_DATASOURCE_DB_KIND: postgresql
      QUARKUS_HIBERNATE_ORM_DATABASE_GENERATION: update
      QUARKUS_HIBERNATE_ORM_DATABASE_DEFAULT_SCHEMA: polaris
      
      # Additional PostgreSQL settings
      QUARKUS_DATASOURCE_JDBC_MAX_SIZE: 20
      QUARKUS_DATASOURCE_JDBC_MIN_SIZE: 5
      
      # S3 Configuration for data storage
      AWS_REGION: ${aws_region}
      AWS_DEFAULT_REGION: ${aws_region}
      S3_BUCKET: ${s3_warehouse_bucket}
      S3_PREFIX: warehouse/
      
      # Polaris Configuration
      POLARIS_PORT: 8181
      POLARIS_ADMIN_PORT: 8182
      POLARIS_REALM: ${polaris_realm}
      CLIENT_ID: root
      CLIENT_SECRET: ${client_secret}
      
      # Persistence type
      POLARIS_PERSISTENCE_TYPE: database
      
      # Logging
      QUARKUS_LOG_LEVEL: INFO
      QUARKUS_LOG_CATEGORY_ORG_APACHE_POLARIS_LEVEL: DEBUG
    ports:
      - "8181:8181"
      - "8182:8182"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8182/q/health"]
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

  ogc-api-features:
    image: ${ecr_ogc_api_image}
    container_name: ogc-api-features
    environment:
      # Polaris connection
      POLARIS_ENDPOINT: http://polaris-catalog:8181
      POLARIS_CATALOG: default
      CLIENT_ID: root
      CLIENT_SECRET: ${client_secret}
      
      # DuckDB configuration
      DUCKDB_EXTENSIONS: httpfs,spatial,iceberg
      DUCKDB_S3_REGION: ${aws_region}
      # Uses IAM role, no explicit credentials needed
      
      # OGC API configuration
      API_HOST: 0.0.0.0
      API_PORT: 8080
      API_TITLE: "Geospatial Data Platform OGC API"
      API_VERSION: "1.0.0"
      
      # Performance tuning
      WORKERS: 4
      CACHE_TTL: 300
      MAX_FEATURES: 10000
    ports:
      - "8080:8080"
    depends_on:
      polaris-catalog:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/"]
      interval: 30s
      timeout: 10s
      retries: 5
    restart: unless-stopped
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

networks:
  default:
    name: geospatial-network
    driver: bridge
COMPOSEEOF

# Substitute RDS variables in docker-compose.yml
sed -i "s/\$RDS_ENDPOINT/$RDS_ENDPOINT/g" docker-compose.yml
sed -i "s/\$RDS_PORT/$RDS_PORT/g" docker-compose.yml

# Set proper permissions
chown -R ec2-user:ec2-user /home/ec2-user/deployment
chmod 600 .env

# Log into ECR
echo "Logging into ECR..."
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin ${ecr_registry}

# Pull images
echo "Pulling Docker images..."
docker pull ${ecr_polaris_image}
docker pull ${ecr_ogc_api_image}

# Start services
echo "Starting Docker Compose services..."
docker-compose up -d

# Wait for Polaris to be healthy
echo "Waiting for Polaris to be healthy..."
MAX_ATTEMPTS=30
ATTEMPT=0
while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
  if docker exec polaris-catalog curl -sf http://localhost:8182/q/health > /dev/null 2>&1; then
    echo "Polaris is healthy!"
    break
  fi
  ATTEMPT=$((ATTEMPT + 1))
  echo "Attempt $ATTEMPT/$MAX_ATTEMPTS - Polaris not ready yet..."
  sleep 10
done

if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
  echo "WARNING: Polaris did not become healthy within expected time"
  echo "Checking Polaris logs..."
  docker logs polaris-catalog --tail 100
fi

# Bootstrap Polaris with PostgreSQL backend
echo "Bootstrapping Polaris catalog with PostgreSQL..."
sleep 10  # Give Polaris a moment to fully initialize

# Check if already bootstrapped by looking for existing data
BOOTSTRAP_CHECK=$(docker exec polaris-catalog curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer root:${client_secret}" \
  http://localhost:8181/v1/config || echo "000")

if [ "$BOOTSTRAP_CHECK" = "200" ]; then
  echo "Polaris appears to be already bootstrapped"
else
  echo "Running Polaris bootstrap..."
  
  # Try to bootstrap via API
  docker exec polaris-catalog curl -X POST \
    http://localhost:8181/v1/bootstrap \
    -H "Content-Type: application/json" \
    -d '{
      "type": "database",
      "realm": "${polaris_realm}",
      "rootCredentials": {
        "clientId": "root",
        "clientSecret": "${client_secret}"
      }
    }' || echo "Bootstrap via API may not be supported, trying CLI..."
  
  # Alternative: Bootstrap via CLI if available
  if docker exec polaris-catalog test -f /opt/polaris/bin/polaris; then
    docker exec polaris-catalog /opt/polaris/bin/polaris bootstrap \
      --type database \
      --realm ${polaris_realm} \
      --root-client-id root \
      --root-client-secret ${client_secret} || echo "Bootstrap may have already been completed"
  fi
fi

# Create default namespace if it doesn't exist
echo "Creating default namespace..."
docker exec polaris-catalog curl -X POST \
  -H "Authorization: Bearer root:${client_secret}" \
  -H "Content-Type: application/json" \
  http://localhost:8181/v1/namespaces \
  -d '{"name": "default", "properties": {}}' || echo "Namespace may already exist"

# Display service status
echo "=== Service Status ==="
docker-compose ps

# Show logs tail
echo "=== Recent Polaris Logs ==="
docker logs polaris-catalog --tail 20

echo "=== Recent OGC API Logs ==="
docker logs ogc-api-features --tail 20

# Create status check script
cat > /home/ec2-user/check-status.sh << 'EOF'
#!/bin/bash
echo "=== Service Status ==="
docker-compose ps
echo ""
echo "=== Polaris Health ==="
curl -s http://localhost:8182/q/health | jq . 2>/dev/null || echo "Polaris health check failed"
echo ""
echo "=== OGC API Status ==="
curl -s http://localhost:8080/ | jq . 2>/dev/null || echo "OGC API check failed"
echo ""
echo "=== Database Connection ==="
PGPASSWORD="${db_password}" psql -h ${db_host} -p ${db_port} -U ${db_username} -d ${db_name} -c "SELECT 'PostgreSQL connected successfully' as status;"
EOF
chmod +x /home/ec2-user/check-status.sh
chown ec2-user:ec2-user /home/ec2-user/check-status.sh

echo "=== Deployment Complete at $(date) ==="
echo "Polaris endpoint: http://$PUBLIC_IP:8181"
echo "OGC API endpoint: http://$PUBLIC_IP:8080"
echo ""
echo "IMPORTANT: Save these connection details:"
echo "  Polaris: http://$PUBLIC_IP:8181"
echo "  OGC API: http://$PUBLIC_IP:8080"
echo "  Client ID: root"
echo "  Client Secret: ${client_secret}"
echo ""
echo "To check status later, run: /home/ec2-user/check-status.sh"
