#!/bin/bash
set -e

EC2_IP=$1

if [ -z "$EC2_IP" ]; then
    echo "Usage: $0 <ec2_ip>"
    exit 1
fi

echo "Running health checks against $EC2_IP..."

# Function to check endpoint
check_endpoint() {
    local url=$1
    local name=$2
    local max_attempts=30
    local attempt=1
    
    echo "Checking $name at $url..."
    
    while [ $attempt -le $max_attempts ]; do
        if curl -f -s -o /dev/null "$url"; then
            echo "✓ $name is healthy"
            return 0
        fi
        
        echo "  Attempt $attempt/$max_attempts failed, waiting..."
        sleep 10
        attempt=$((attempt + 1))
    done
    
    echo "✗ $name health check failed after $max_attempts attempts"
    return 1
}

# Check Polaris
check_endpoint "http://$EC2_IP:8181/v1/config" "Polaris Catalog"

# Check OGC API
check_endpoint "http://$EC2_IP:8080/health" "OGC API Features"
check_endpoint "http://$EC2_IP:8080/" "OGC API Landing Page"
check_endpoint "http://$EC2_IP:8080/conformance" "OGC API Conformance"
check_endpoint "http://$EC2_IP:8080/collections" "OGC API Collections"

echo ""
echo "========================================="
echo "All health checks passed!"
echo "========================================="
echo "Polaris Catalog: http://$EC2_IP:8181"
echo "OGC API Features: http://$EC2_IP:8080"
echo "========================================="