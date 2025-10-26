#!/bin/bash
set -e

# Update system
dnf update -y

# Install Docker
dnf install -y docker

# Start and enable Docker
systemctl start docker
systemctl enable docker

# Add ec2-user to docker group
usermod -aG docker ec2-user

# Install Docker Compose
DOCKER_COMPOSE_VERSION="2.23.0"
curl -L "https://github.com/docker/compose/releases/download/v$${DOCKER_COMPOSE_VERSION}/docker-compose-linux-aarch64" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

# Install AWS CLI v2 (should be pre-installed on AL2023)
if ! command -v aws &> /dev/null; then
    curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    ./aws/install
    rm -rf aws awscliv2.zip
fi

# Configure AWS CLI default region
mkdir -p /home/ec2-user/.aws
cat > /home/ec2-user/.aws/config << EOF
[default]
region = ${aws_region}
output = json
EOF
chown -R ec2-user:ec2-user /home/ec2-user/.aws

# Install additional tools
dnf install -y git jq htop

# Create deployment directory
mkdir -p /home/ec2-user/deployment
chown -R ec2-user:ec2-user /home/ec2-user/deployment

# Set environment variables for deployment
cat > /home/ec2-user/.env << EOF
AWS_REGION=${aws_region}
S3_BUCKET=${s3_bucket}
DYNAMODB_TABLE=${dynamodb_table}
ECR_REGISTRY=${ecr_registry}
EOF
chown ec2-user:ec2-user /home/ec2-user/.env

# Configure Docker to use ECR credential helper
mkdir -p /home/ec2-user/.docker
cat > /home/ec2-user/.docker/config.json << EOF
{
  "credHelpers": {
    "${ecr_registry}": "ecr-login"
  }
}
EOF
chown -R ec2-user:ec2-user /home/ec2-user/.docker

# Install ECR credential helper
dnf install -y amazon-ecr-credential-helper

# Enable CloudWatch agent (optional)
dnf install -y amazon-cloudwatch-agent

# Create log directory
mkdir -p /var/log/geospatial-platform
chown -R ec2-user:ec2-user /var/log/geospatial-platform

# Signal completion
touch /home/ec2-user/user_data_complete
chown ec2-user:ec2-user /home/ec2-user/user_data_complete

echo "User data script completed successfully" > /var/log/user_data.log