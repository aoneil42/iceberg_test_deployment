#!/bin/bash
set -e

echo "Starting Polaris with PostgreSQL backend..."

# Wait for PostgreSQL to be available
echo "Waiting for PostgreSQL at ${POSTGRES_HOST}:${POSTGRES_PORT}..."
until PGPASSWORD="${POSTGRES_PASSWORD}" psql -h "${POSTGRES_HOST}" -p "${POSTGRES_PORT}" -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -c '\q' 2>/dev/null; do
  echo "PostgreSQL is unavailable - sleeping"
  sleep 2
done

echo "✅ PostgreSQL is available!"

# Create polaris-server.yml with PostgreSQL configuration
cat > /app/polaris-server.yml <<EOF
server:
  applicationConnectors:
    - type: http
      port: 8181
  adminConnectors:
    - type: http
      port: 8182

logging:
  level: INFO
  appenders:
    - type: console

metastore:
  type: postgres
  host: ${POSTGRES_HOST}
  port: ${POSTGRES_PORT}
  database: ${POSTGRES_DB}
  username: ${POSTGRES_USER}
  password: ${POSTGRES_PASSWORD}
  
  # Connection pool settings
  maxConnections: 10
  minConnections: 2

# Authentication configuration
authentication:
  type: oauth2
  clients:
    - id: ${POLARIS_CLIENT_ID}
      secret: ${POLARIS_CLIENT_SECRET}
      scopes:
        - PRINCIPAL_ROLE:ALL
        - CATALOG_MANAGE_CONTENT
        - CATALOG_MANAGE_ACCESS

# Default catalog configuration
defaultCatalog:
  warehouse: s3://${S3_WAREHOUSE_BUCKET}/warehouse/
  storageType: S3
  s3:
    region: ${AWS_REGION}
    pathStyleAccess: false

# CORS configuration for OGC API
cors:
  allowedOrigins:
    - "*"
  allowedHeaders:
    - "*"
  allowedMethods:
    - GET
    - POST
    - PUT
    - DELETE
    - OPTIONS
EOF

echo "Starting Polaris server..."
exec java ${JAVA_OPTS} -jar /app/polaris-server.jar server /app/polaris-server.yml
