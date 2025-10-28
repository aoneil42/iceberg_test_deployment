# Iceberg Test Deployment

Complete cloud-native geospatial data platform with Polaris catalog, S3 storage, OGC API Features, and deck.gl visualization.

## Architecture

```
┌─────────────┐
│  Frontend   │  deck.gl with GeoArrow/GeoJSON
│  (deck.gl)  │
└──────┬──────┘
       │ HTTP
       ▼
┌─────────────────────┐
│ OGC API Features    │  FastAPI + DuckDB
│    Port 8080        │  Query Engine
└──────┬──────────────┘
       │ REST Catalog API
       ▼
┌─────────────────────┐
│  Apache Polaris     │  Iceberg Catalog
│    Port 8181        │
└──────┬──────────────┘
       │
       ▼
┌─────────────────────────────────────┐
│        AWS Infrastructure           │
│  ┌───────┐  ┌──────────────────┐   │
│  │  S3   │  │  RDS PostgreSQL  │   │
│  │ Data  │  │    Metadata      │   │
│  └───────┘  └──────────────────┘   │
│                                     │
│  GeoParquet + Iceberg Tables        │
│  H3 Partitioned (Res 5)             │
└─────────────────────────────────────┘
```

## Features

✅ **Cloud-Native**: Fully automated deployment on AWS  
✅ **ACID Transactions**: Iceberg provides atomicity and consistency  
✅ **OGC Compliant**: Standards-based API for interoperability  
✅ **High Performance**: DuckDB query engine with spatial indexing  
✅ **Modern Frontend**: deck.gl with GeoArrow support  
✅ **Cost-Optimized**: ~$25-40/month with manual start/stop  
✅ **GitHub Actions**: Fully automated infrastructure and deployment  

## Cost Breakdown

**With manual start/stop (recommended for dev/test):**

| Usage Pattern | Monthly Cost |
|---------------|--------------|
| 5 days/month  | ~$10-15     |
| Half month    | ~$18-25     |
| Always on     | ~$30-40     |

**Cost components:**
- EC2 t4g.medium (ARM): $0.0336/hour when running
- RDS PostgreSQL t4g.micro: $0.016/hour when running  
- S3 storage: ~$2-3/month
- Data transfer: ~$1-2/month

## Prerequisites

- AWS Account with programmatic access
- GitHub account (for CI/CD)
- Terraform 1.6+
- Docker (for local testing)

## Quick Start

### 1. Configure GitHub Secrets

In your GitHub repository settings → Secrets and variables → Actions, add:

```
AWS_ACCESS_KEY_ID: <your-access-key>
AWS_SECRET_ACCESS_KEY: <your-secret-key>
DB_MASTER_PASSWORD: <secure-password-for-rds>
```

### 2. Deploy Infrastructure

```bash
# Push to main branch triggers automatic deployment
git push origin main

# OR manually trigger deployment workflow
# Go to Actions → Deploy Infrastructure → Run workflow
```

This will:
1. Create VPC, subnets, security groups
2. Provision RDS PostgreSQL database
3. Launch EC2 instance (t4g.medium ARM)
4. Create S3 bucket for Iceberg warehouse
5. Set up ECR repositories for Docker images
6. Deploy Polaris and OGC API containers

### 3. Start/Stop Infrastructure

**To start (when stopped):**
```bash
# Go to Actions → Start Infrastructure → Run workflow
```

**To stop (to save costs):**
```bash
# Go to Actions → Stop Infrastructure → Run workflow
```

Both EC2 and RDS will start/stop together automatically.

## Architecture Components

### Data Layer
- **S3**: Object storage for GeoParquet files and Iceberg metadata
- **RDS PostgreSQL**: Polaris catalog metadata store (t4g.micro)
- **Iceberg**: Table format with ACID guarantees

### Compute Layer  
- **EC2 (t4g.medium)**: ARM-based compute running Docker containers
- **Apache Polaris**: Iceberg REST catalog (port 8181)
- **DuckDB**: Analytical query engine with spatial extensions
- **FastAPI**: OGC API Features implementation (port 8080)

### Visualization Layer
- **deck.gl**: WebGL-powered geospatial visualization
- **GeoArrow**: Efficient columnar data transfer format
- **H3**: Hexagonal spatial indexing (resolution 5)

## Usage

### Accessing Services

After deployment, find your EC2 public IP in the GitHub Actions output:

```bash
# Polaris Catalog
http://<EC2_IP>:8181/v1/config

# OGC API Features
http://<EC2_IP>:8080/

# Frontend (local)
cd frontend
# Open index.html and enter: http://<EC2_IP>:8080
```

### Loading Data

```bash
cd etl
pip install -r requirements.txt

python examples/sample_load.py \
  --input your_data.geojson \
  --table my_features \
  --polaris-endpoint http://<EC2_IP>:8181 \
  --s3-bucket <your-s3-bucket>
```

### Querying with DuckDB

```python
import duckdb

conn = duckdb.connect()
conn.execute("LOAD iceberg")
conn.execute("LOAD spatial")
conn.execute("SET s3_region='us-west-2'")

# Connect to Polaris catalog
conn.execute("""
CREATE CATALOG polaris FROM iceberg(
    'rest',
    uri='http://<EC2_IP>:8181/v1/polaris'
)
""")

# Query features
result = conn.execute("""
SELECT * FROM polaris.default.my_features
WHERE ST_Intersects(
    ST_GeomFromWKB(geometry),
    ST_GeomFromText('POLYGON((-180 -90, 180 -90, 180 90, -180 90, -180 -90))')
)
LIMIT 10
""").fetchall()
```

## Managing Costs

### Manual Start/Stop

Use GitHub Actions workflows:
- **Start Infrastructure**: Starts both EC2 and RDS
- **Stop Infrastructure**: Stops both EC2 and RDS

**Note:** RDS automatically restarts after 7 days if stopped.

### Always-On vs. Start/Stop Comparison

| Scenario | EC2 Cost | RDS Cost | Storage | Total |
|----------|----------|----------|---------|-------|
| **5 days/month** | $1.92 | $1.92 | $6.30 | **~$10** |
| **Half month** | $5.76 | $5.76 | $6.30 | **~$18** |
| **Always on** | $11.52 | $11.52 | $6.30 | **~$30** |

## Monitoring

### Check Service Health

```bash
# SSH to EC2 (if key_name configured)
ssh ec2-user@<EC2_IP>

# Or use AWS Session Manager (no SSH key needed)
aws ssm start-session --target <INSTANCE_ID>

# Check containers
cd ~/deployment
docker-compose ps

# View logs
docker-compose logs -f polaris-catalog
docker-compose logs -f ogc-api-features
```

### Check Database Connection

```bash
# From EC2 instance
docker exec -it polaris-catalog /bin/bash

# Test DB connection
psql "postgresql://polaris_admin:<password>@<RDS_ENDPOINT>:5432/polaris" -c "SELECT version();"
```

## Troubleshooting

### Polaris Won't Start

```bash
# Check logs
docker logs polaris-catalog --tail 100

# Check RDS connectivity
nc -zv <RDS_ENDPOINT> 5432

# Verify environment variables
cat ~/deployment/.env
```

### RDS Connection Issues

1. Verify RDS is running:
```bash
aws rds describe-db-instances \
  --db-instance-identifier iceberg-test-polaris-db \
  --query 'DBInstances[0].DBInstanceStatus'
```

2. Check security groups allow EC2 → RDS on port 5432

3. Verify credentials in Terraform outputs:
```bash
cd terraform
terraform output deployment_commands
```

### OGC API Can't Connect to Polaris

```bash
# Check if Polaris is healthy
curl http://localhost:8182/q/health

# Restart containers
cd ~/deployment
docker-compose restart
```

## Cleanup

### Stop Infrastructure (Keep for Later)

```bash
# Use GitHub Actions: Stop Infrastructure workflow
```

### Destroy Everything

```bash
# Use GitHub Actions: Deploy workflow with "destroy" action
# OR from local machine:
cd terraform
terraform destroy
```

## Security Considerations

**Current setup (evaluation/testing):**
- ⚠️ No authentication on Polaris or OGC API
- ⚠️ RDS accessible from EC2 only (not public)
- ⚠️ SSH may be open (depending on `allowed_ssh_cidr`)

**For production:**
1. Enable Polaris OAuth authentication
2. Add API Gateway with IAM auth
3. Implement JWT tokens in OGC API
4. Use AWS Secrets Manager for DB credentials
5. Enable MFA delete on S3 bucket
6. Configure CloudTrail for audit logs
7. Restrict security group rules to specific IPs

## Technology Stack

- **Storage**: S3, RDS PostgreSQL 16
- **Compute**: EC2 (t4g.medium ARM), Docker
- **Catalog**: Apache Polaris 1.1.0
- **Query Engine**: DuckDB with spatial extensions
- **API**: FastAPI (OGC API Features)
- **Visualization**: deck.gl, GeoArrow
- **Table Format**: Apache Iceberg
- **Data Format**: GeoParquet
- **Spatial Index**: H3 (resolution 5)
- **CI/CD**: GitHub Actions
- **IaC**: Terraform

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

MIT License - See LICENSE file for details

## Support

For issues or questions:
- Check the Troubleshooting section
- Review CloudWatch logs
- Open a GitHub issue

---

Built with ❤️ for modern geospatial data platforms
