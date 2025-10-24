#!/bin/bash
set -e

# This script is run on the EC2 instance to deploy the application

echo "Starting deployment..."

cd ~/deployment

# Pull latest images
echo "Pulling Docker images..."
docker-compose pull

# Stop existing containers
echo "Stopping existing containers..."
docker-compose down || true

# Start services
echo "Starting services..."
docker-compose up -d

# Wait for services to be healthy
echo "Waiting for services to become healthy..."
sleep 30

# Check service status
echo "Checking service status..."
docker-compose ps

echo "Deployment complete!"