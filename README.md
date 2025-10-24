# Geospatial Platform - Cloud-Native Architecture

Complete cloud-native geospatial data platform with Polaris catalog, S3 storage, OGC API Features, and deck.gl visualization.

## Architecture Overview

```
┌─────────────┐
│  Frontend   │  deck.gl with GeoArrow/GeoJSON
│  (deck.gl)  │
└──────┬──────┘
       │ HTTP
       ▼
┌─────────────────────┐
│   OGC API Features  │  FastAPI + DuckDB
│   Port 8080         │  Query Engine
└──────┬──────────────┘
       │ REST Catalog API
       ▼
┌─────────────────────┐
│  Apache Polaris     │  Iceberg Catalog
│  Port 8181          │
└──────┬──────────────┘
       │
       ▼
┌─────────────────────────────────┐
│  AWS Infrastructure             │
│  ┌───────┐  ┌──────────────┐   │
│  │   S3  │  │  DynamoDB    │   │
│  │ Data  │  │  Metadata    │   │
│  └───────┘  └──────────────┘   │
│                                 │
│  GeoParquet + Iceberg Tables    │
│  H3 Partitioned (Res 5)         │
└─────────────────────────────────┘
```

## Features

✅ **Cloud-Native**: Fully automated deployment on AWS  
✅ **ACID Transactions**: Iceberg provides atomicity and consistency  
✅ **OGC Compliant**: Standards-based API for interoperability  
✅ **High Performance**: DuckDB query engine with spatial indexing  
✅ **Modern Frontend**: deck.gl with GeoArrow support  
✅ **Cost-Optimized**: ~$15-20/month with manual start/stop  
✅ **GitLab CI/CD**: Fully automated infrastructure and deployment  

## Prerequisites

- AWS Account with programmatic access
- GitLab account (for CI/CD)
- Terraform 1.6+
- Docker
- Python 3.11+
- Node.js 18+ (for frontend development)

## Quick Start

### 1. Setup GitLab CI/CD Variables

In GitLab project settings → CI/CD → Variables, add:

```
AWS_ACCESS_KEY_ID: <your-access-key>
AWS_SECRET_ACCESS_KEY: <your-secret-key>
AWS_ACCOUNT_ID: <your-account-id>
AWS_REGION: us-west-2
SSH_PRIVATE_KEY: <your-ssh-private-key>
TERRAFORM_STATE_BUCKET: <create-manually-first>
```

### 2. Create Terraform State Bucket

```bash
aws s3 mb s3://your-terraform-state-bucket --region us-west-2
aws s3api put-bucket-versioning \
    --bucket your-terraform-state-bucket \
    --versioning-configuration Status=Enabled
```

### 3. Update Configuration

Edit `terraform/variables.tf`:
- Set `allowed_ssh_cidr` to your IP address
- Optionally set `key_name` for SSH access

### 4. Deploy

```bash
# Push to main branch
git add .
git commit -m "Initial deployment"
git push origin main

# In GitLab CI/CD, manually trigger:
# 1. deploy-infra (deploys AWS infrastructure)
# 2. deploy-app (deploys Docker containers)
```

### 5. Access Services

After deployment completes, find your EC2 IP in Terraform outputs:

```bash
# Polaris Catalog
http://<EC2_IP>:8181/v1/config

# OGC API Features
http://<EC2_IP>:8080/

# Frontend
Open frontend/src/index.html and enter: http://<EC2_IP>:8080
```

## Loading Data

### Using Python ETL Script

```bash
cd etl
pip install -r requirements.txt

python examples/sample_load.py \
    --input your_data.geojson \
    --table my_features \
    --polaris-endpoint http://<EC2_IP>:8181 \
    --s3-bucket <your-s3-bucket>
```

### Using DuckDB CLI

```bash
export POLARIS_ENDPOINT=http://<EC2_IP>:8181
export S3_BUCKET=<your-s3-bucket>

duckdb < etl/scripts/ingest_geojson.sql
```

## Project Structure

```
geospatial-platform/
├── .gitlab-ci.yml              # CI/CD pipeline
├── README.md                   # This file
├── terraform/                  # Infrastructure as Code
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── ec2.tf
│   ├── s3.tf
│   ├── dynamodb.tf
│   ├── iam.tf
│   ├── security_groups.tf
│   ├── ecr.tf
│   └── user_data.sh
├── docker/                     # Application containers
│   ├── polaris/
│   │   ├── Dockerfile
│   │   ├── polaris-server.yml
│   │   └── entrypoint.sh
│   ├── ogc-api/
│   │   ├── Dockerfile
│   │   ├── requirements.txt
│   │   └── app/
│   └── docker-compose.yml.template
├── etl/                        # ETL scripts
│   ├── requirements.txt
│   └── examples/
│       └── sample_load.py
├── scripts/                    # Deployment scripts
│   ├── deploy.sh
│   └── health_check.sh
└── frontend/                   # deck.gl application
    ├── package.json
    └── src/
```

## Technology Stack

### Infrastructure
- **AWS EC2** (t4g.medium) - ARM-based compute
- **AWS S3** - Object storage for data
- **AWS DynamoDB** - Catalog metadata
- **AWS ECR** - Container registry

### Application
- **Apache Polaris** - Iceberg REST catalog
- **DuckDB** - Analytical query engine
- **FastAPI** - OGC API implementation
- **deck.gl** - WebGL-powered visualization

### Data Format
- **Apache Iceberg** - Table format with ACID
- **GeoParquet** - Columnar geospatial format
- **H3** - Hexagonal spatial indexing (res 5)

## Query Examples

### OGC API Features

```bash
# List collections
curl http://<EC2_IP>:8080/collections

# Get features with bbox
curl "http://<EC2_IP>:8080/collections/my_features/items?bbox=-180,-90,180,90&limit=100"

# Get features as GeoArrow
curl -H "Accept: application/vnd.apache.arrow.stream" \
  "http://<EC2_IP>:8080/collections/my_features/items?bbox=-180,-90,180,90"
```

### Direct DuckDB Queries

```python
import duckdb

conn = duckdb.connect()
conn.execute("LOAD iceberg")
conn.execute("LOAD spatial")
conn.execute(f"SET s3_region='us-west-2'")

# Connect to Polaris catalog
conn.execute(f"""
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

## Operational Tasks

### Start/Stop EC2 Instance

```bash
# Stop (saves money when not in use)
aws ec2 stop-instances --instance-ids <instance-id>

# Start
aws ec2 start-instances --instance-ids <instance-id>
```

### View Logs

```bash
ssh ec2-user@<EC2_IP>
cd ~/deployment
docker-compose logs -f
```

### Update Application

```bash
# Make code changes, commit, push
git push origin main

# In GitLab, manually trigger deploy-app stage
```

### Cleanup

```bash
# In GitLab CI/CD, or locally:
cd terraform
terraform destroy -auto-approve
```

## Cost Estimate

**Monthly costs (us-west-2, 8 hours/day usage):**

| Service | Cost |
|---------|------|
| EC2 t4g.medium | ~$8 |
| EBS 30GB | $2.40 |
| S3 (100GB) | $2.30 |
| DynamoDB | $1 |
| Data Transfer | $1 |
| ECR | $0.20 |
| CloudWatch | $0.50 |
| **Total** | **~$15-20/month** |

**Full month (24/7):** ~$35-40/month

## Troubleshooting

### Services Not Starting

```bash
ssh ec2-user@<EC2_IP>
cd ~/deployment

# Check container status
docker-compose ps

# View logs
docker-compose logs polaris
docker-compose logs ogc-api

# Restart services
docker-compose restart
```

### Polaris Connection Issues

```bash
# Check Polaris health
curl http://<EC2_IP>:8181/v1/config

# Check DynamoDB table
aws dynamodb describe-table --table-name <table-name>

# Check S3 bucket permissions
aws s3 ls s3://<bucket-name>/
```

### OGC API Query Errors

```bash
# Test catalog connection
docker exec -it ogc-api-features python -c "
from app.duckdb_client import get_duckdb_client
client = get_duckdb_client()
print(client.list_tables())
"

# Check DuckDB logs
docker logs ogc-api-features
```

### ETL Issues

```bash
# Test Polaris connection
curl http://<EC2_IP>:8181/v1/polaris/namespaces

# Test S3 access
aws s3 ls s3://<bucket-name>/warehouse/

# Run ETL with verbose logging
python etl/examples/sample_load.py --input data.geojson ... -v
```

## Performance Optimization

### Query Performance

1. **Partition Pruning**: H3 cells at resolution 5 provide ~252 global partitions
2. **Spatial Indexing**: DuckDB's spatial extension efficiently filters geometries
3. **Columnar Format**: GeoParquet enables column pruning and compression
4. **Arrow IPC**: GeoArrow reduces serialization overhead vs GeoJSON

### Scaling Considerations

For production workloads:

1. **Increase EC2 size**: t4g.large or t4g.xlarge for more queries/sec
2. **Add ElastiCache**: Cache frequently accessed tiles/queries
3. **Use ALB**: Load balance multiple OGC API instances
4. **Enable DynamoDB Auto-scaling**: For high catalog operations
5. **Use CloudFront**: CDN for static frontend assets

## Security Best Practices

### For Production

1. **Restrict Security Groups**:
   ```hcl
   allowed_ssh_cidr = "YOUR_IP/32"
   allowed_api_cidr = "YOUR_IP/32"
   ```

2. **Enable HTTPS**:
   - Add Application Load Balancer
   - Use AWS Certificate Manager for SSL/TLS
   - Update OGC API to use HTTPS URLs

3. **Enable Authentication**:
   - Configure Polaris OAuth authentication
   - Add API Gateway with AWS IAM auth
   - Implement JWT tokens in OGC API

4. **Enable Encryption**:
   - S3 bucket encryption (already enabled with AES256)
   - EBS volume encryption (already enabled)
   - Enable DynamoDB encryption at rest

5. **Audit Logging**:
   - Enable CloudTrail for AWS API calls
   - Configure CloudWatch log retention
   - Monitor security group changes

## Advanced Features

### Time Travel Queries

```python
# Query historical snapshot
conn.execute("""
SELECT * FROM polaris.default.my_features 
FOR VERSION AS OF '<snapshot-id>'
""")

# List snapshots
conn.execute("""
SELECT * FROM polaris.default.my_features$snapshots
ORDER BY committed_at DESC
""")
```

### Schema Evolution

```python
# Add column without rewriting data
conn.execute("""
ALTER TABLE polaris.default.my_features 
ADD COLUMN new_property VARCHAR
""")
```

### Incremental Updates

```python
# Append new data
conn.execute("""
INSERT INTO polaris.default.my_features
SELECT * FROM source_table
""")

# Merge updates (upsert)
conn.execute("""
MERGE INTO polaris.default.my_features AS target
USING source_table AS source
ON target.id = source.id
WHEN MATCHED THEN UPDATE SET *
WHEN NOT MATCHED THEN INSERT *
""")
```

### Custom H3 Resolution

For different use cases:

```python
# Coarse (res 4): ~7,000 km² per cell - global/continental scale
# Medium (res 5): ~1,000 km² per cell - regional scale (default)
# Fine (res 6): ~150 km² per cell - metropolitan scale
# Very Fine (res 7): ~21 km² per cell - urban scale

# Change resolution in ETL
python sample_load.py ... --h3-resolution 6
```

## API Reference

### Polaris Catalog API

```bash
# Get config
GET http://<EC2_IP>:8181/v1/config

# List namespaces
GET http://<EC2_IP>:8181/v1/polaris/namespaces

# List tables
GET http://<EC2_IP>:8181/v1/polaris/namespaces/default/tables

# Get table metadata
GET http://<EC2_IP>:8181/v1/polaris/namespaces/default/tables/<table-name>
```

### OGC API Features

```bash
# Landing page
GET http://<EC2_IP>:8080/

# Conformance
GET http://<EC2_IP>:8080/conformance

# Collections
GET http://<EC2_IP>:8080/collections

# Collection metadata
GET http://<EC2_IP>:8080/collections/{collectionId}

# Features (GeoJSON)
GET http://<EC2_IP>:8080/collections/{collectionId}/items
  ?bbox=minx,miny,maxx,maxy
  &limit=1000
  &offset=0
  &properties=prop1,prop2

# Features (GeoArrow)
GET http://<EC2_IP>:8080/collections/{collectionId}/items?f=arrow
Accept: application/vnd.apache.arrow.stream
```

## Contributing

This is an evaluation/reference architecture. For production use:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## Known Limitations

1. **No Authentication**: Current implementation has no auth (eval only)
2. **Single Instance**: No high availability or load balancing
3. **Manual Start/Stop**: No auto-scaling or scheduled start/stop
4. **Limited Monitoring**: Basic CloudWatch only
5. **GeoArrow Parsing**: Frontend needs enhanced Arrow geometry parsing
6. **No Backups**: Manual backup strategy required for production

## Roadmap

Future enhancements:

- [ ] OAuth authentication for Polaris
- [ ] API Gateway integration
- [ ] Multi-instance deployment with ALB
- [ ] CloudFront distribution
- [ ] Enhanced monitoring with Grafana
- [ ] Automated backup/restore
- [ ] Support for additional OGC standards (Tiles, Processes)
- [ ] Real-time change data capture
- [ ] Advanced caching strategies

## Resources

- [Apache Polaris Documentation](https://polaris.apache.org/)
- [Apache Iceberg Documentation](https://iceberg.apache.org/)
- [DuckDB Spatial Extension](https://duckdb.org/docs/extensions/spatial.html)
- [OGC API Features Specification](https://ogcapi.ogc.org/features/)
- [deck.gl Documentation](https://deck.gl/)
- [H3 Spatial Index](https://h3geo.org/)

## License

MIT License - See LICENSE file for details

## Support

For issues or questions:

1. Check the Troubleshooting section
2. Review CloudWatch logs
3. Open a GitLab issue
4. Contact: [your-email@example.com]

---

**Built with ❤️ for modern geospatial data platforms**