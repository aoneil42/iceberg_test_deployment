#!/bin/bash
set -e

# Log everything to both console and file
exec > >(tee -a /var/log/user-data.log)
exec 2>&1

echo "=== Starting user data script at $(date) ==="

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

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

# Install Session Manager plugin for troubleshooting
yum install -y amazon-ssm-agent
systemctl start amazon-ssm-agent
systemctl enable amazon-ssm-agent

# Get instance metadata
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

echo "Region: $REGION"
echo "Instance ID: $INSTANCE_ID"

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
  
  echo "Waiting for RDS to become available..."
  aws rds wait db-instance-available \
    --db-instance-identifier $RDS_INSTANCE_ID \
    --region $REGION
  
  echo "RDS is now available"
elif [ "$RDS_STATE" = "available" ]; then
  echo "RDS is already available"
else
  echo "RDS state: $RDS_STATE - waiting for it to become available..."
  aws rds wait db-instance-available \
    --db-instance-identifier $RDS_INSTANCE_ID \
    --region $REGION \
    --max-attempts 60 \
    --delay 10 || echo "Warning: RDS wait timeout"
fi

# Get RDS endpoint
RDS_ENDPOINT=$(aws rds describe-db-instances \
  --db-instance-identifier $RDS_INSTANCE_ID \
  --region $REGION \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text)

echo "RDS Endpoint: $RDS_ENDPOINT"

# Create deployment directory
mkdir -p /home/ec2-user/deployment
cd /home/ec2-user/deployment

# Create .env file with configuration
cat > .env << 'ENVEOF'
# AWS Configuration
AWS_REGION=${aws_region}

# ECR Images
POLARIS_IMAGE=${polaris_image}
OGC_API_IMAGE=${ogc_api_image}

# Database Configuration
DB_ENDPOINT=$RDS_ENDPOINT
DB_NAME=${db_name}
DB_USERNAME=${db_username}
DB_PASSWORD=${db_password}

# S3 Configuration
S3_WAREHOUSE_BUCKET=${s3_warehouse_bucket}
ENVEOF

# Substitute the RDS endpoint in .env
sed -i "s/\$RDS_ENDPOINT/$RDS_ENDPOINT/" .env

# Create docker-compose.yml
cat > docker-compose.yml << 'COMPOSEEOF'
${docker_compose_content}
COMPOSEEOF

# Set proper permissions
chown -R ec2-user:ec2-user /home/ec2-user/deployment
chmod 600 .env

# Log into ECR
echo "Logging into ECR..."
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin ${ecr_registry}

# Pull images
echo "Pulling Docker images..."
docker pull ${polaris_image}
docker pull ${ogc_api_image}

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
  docker logs polaris-catalog --tail 50
fi

# Bootstrap Polaris (creates root principal if needed)
echo "Bootstrapping Polaris catalog..."
docker exec polaris-catalog /app/bin/polaris bootstrap || echo "Bootstrap may have already been run"

# Check if bootstrap created credentials
if docker logs polaris-catalog 2>&1 | grep -q "root principal credentials"; then
  echo "=== POLARIS ROOT CREDENTIALS ==="
  docker logs polaris-catalog 2>&1 | grep "root principal credentials" | tail -1
  echo "================================"
  echo "IMPORTANT: Save these credentials! They will be needed to create catalogs."
fi

# Display service status
echo "=== Service Status ==="
docker-compose ps

echo "=== Deployment Complete at $(date) ==="
echo "Polaris endpoint: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8181"
echo "OGC API endpoint: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080"
