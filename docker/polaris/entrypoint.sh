#!/bin/bash
set -e

echo "Starting Apache Polaris..."
echo "AWS Region: ${AWS_REGION}"
echo "S3 Bucket: ${S3_BUCKET}"
echo "DynamoDB Table: ${DYNAMODB_TABLE}"

# Substitute environment variables in config
envsubst < /app/conf/polaris-server.yml > /app/conf/polaris-server-final.yml

# Start Polaris
exec java ${JAVA_OPTS} \
    -jar /app/polaris.jar \
    server \
    /app/conf/polaris-server-final.yml