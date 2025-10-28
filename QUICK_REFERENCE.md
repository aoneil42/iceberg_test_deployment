# Quick Reference Card

## GitHub Actions Workflows

### Main Deployment
```bash
# Automatic on push to main
git push origin main

# Or manual trigger via GitHub UI:
Actions → Deploy Geospatial Platform → Run workflow
```

### Start/Stop EC2
```bash
# Via GitHub UI:
Actions → Start/Stop EC2 Instance → Run workflow → [action]

# Or with GitHub CLI:
gh workflow run start-stop.yml -f action=start
gh workflow run start-stop.yml -f action=stop
gh workflow run start-stop.yml -f action=status
```

## AWS CLI Commands

### Check EC2 Status
```bash
# Get instance ID
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=geospatial-platform" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text

# Get instance status
aws ec2 describe-instances \
  --instance-ids <instance-id> \
  --query 'Reservations[0].Instances[0].State.Name' \
  --output text

# Get public IP
aws ec2 describe-instances \
  --instance-ids <instance-id> \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text
```

### RDS Operations
```bash
# Get RDS endpoint
aws rds describe-db-instances \
  --db-instance-identifier geospatial-platform-polaris-db \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text

# Check RDS status
aws rds describe-db-instances \
  --db-instance-identifier geospatial-platform-polaris-db \
  --query 'DBInstances[0].DBInstanceStatus' \
  --output text

# Create manual snapshot
aws rds create-db-snapshot \
  --db-instance-identifier geospatial-platform-polaris-db \
  --db-snapshot-identifier manual-backup-$(date +%Y%m%d)
```

## SSH to EC2
```bash
# Get EC2 IP first
EC2_IP=$(terraform output -raw ec2_public_ip)

# SSH
ssh ec2-user@$EC2_IP
```

## Docker Commands (on EC2)

### Check Status
```bash
cd ~/deployment

# List containers
docker-compose ps

# Check logs
docker-compose logs polaris
docker-compose logs ogc-api
docker-compose logs -f  # Follow logs

# Check specific container
docker logs polaris-catalog
docker logs ogc-api-features
```

### Restart Services
```bash
cd ~/deployment

# Restart all
docker-compose restart

# Restart specific service
docker-compose restart polaris
docker-compose restart ogc-api

# Stop and remove
docker-compose down

# Start fresh
docker-compose up -d
```

### Update Images
```bash
cd ~/deployment

# Pull latest images
docker-compose pull

# Recreate containers with new images
docker-compose up -d --force-recreate
```

## Health Checks

### Polaris
```bash
# Config endpoint
curl http://<EC2_IP>:8181/v1/config

# List namespaces
curl http://<EC2_IP>:8181/v1/polaris/namespaces

# Check health (on EC2)
docker exec polaris-catalog curl -f http://localhost:8181/v1/config
```

### OGC API
```bash
# Landing page
curl http://<EC2_IP>:8080/

# Collections
curl http://<EC2_IP>:8080/collections

# Health check (on EC2)
docker exec ogc-api-features curl -f http://localhost:8080/
```

### RDS PostgreSQL
```bash
# Connect from EC2
PGPASSWORD='your-password' psql -h <rds-endpoint> -U polaris -d polaris

# List tables
PGPASSWORD='your-password' psql -h <rds-endpoint> -U polaris -d polaris -c '\dt'

# Check connections
PGPASSWORD='your-password' psql -h <rds-endpoint> -U polaris -d polaris \
  -c "SELECT * FROM pg_stat_activity WHERE datname = 'polaris';"
```

## Terraform Operations

### Initialize
```bash
cd terraform

terraform init \
  -backend-config="bucket=<your-state-bucket>" \
  -backend-config="key=geospatial-platform/terraform.tfstate" \
  -backend-config="region=us-west-2"
```

### Plan and Apply
```bash
# Plan
terraform plan \
  -var="db_master_password=$DB_PASSWORD" \
  -var="polaris_client_secret=$POLARIS_SECRET"

# Apply
terraform apply \
  -var="db_master_password=$DB_PASSWORD" \
  -var="polaris_client_secret=$POLARIS_SECRET"

# Auto-approve
terraform apply -auto-approve \
  -var="db_master_password=$DB_PASSWORD" \
  -var="polaris_client_secret=$POLARIS_SECRET"
```

### Get Outputs
```bash
terraform output
terraform output ec2_public_ip
terraform output rds_endpoint
terraform output frontend_url
```

### Destroy (careful!)
```bash
terraform destroy -auto-approve \
  -var="db_master_password=$DB_PASSWORD" \
  -var="polaris_client_secret=$POLARIS_SECRET"
```

## Frontend Operations

### Local Development
```bash
cd frontend

# Install dependencies
npm install

# Start dev server
npm run dev

# Build for production
npm run build

# Preview production build
npm run preview
```

### Deploy to S3 (manual)
```bash
cd frontend
npm run build

# Sync to S3
aws s3 sync dist/ s3://geospatial-platform-frontend-<account-id>/

# Set website configuration
aws s3 website s3://geospatial-platform-frontend-<account-id>/ \
  --index-document index.html
```

## CloudWatch Logs

### View from CLI
```bash
# List log groups
aws logs describe-log-groups --log-group-name-prefix /aws/

# Get latest log events
aws logs tail /aws/ec2/user-data --follow

# Get RDS logs
aws rds download-db-log-file-portion \
  --db-instance-identifier geospatial-platform-polaris-db \
  --log-file-name error/postgresql.log.2024-10-28-00 \
  --output text
```

## Troubleshooting

### Services Won't Start
```bash
# On EC2:
# 1. Check Docker status
systemctl status docker

# 2. Check Docker Compose
cd ~/deployment
docker-compose ps
docker-compose logs

# 3. Check disk space
df -h

# 4. Check memory
free -h
```

### RDS Connection Issues
```bash
# 1. Check security group
aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=*rds*"

# 2. Check RDS status
aws rds describe-db-instances \
  --db-instance-identifier geospatial-platform-polaris-db

# 3. Test connection from EC2
telnet <rds-endpoint> 5432
```

### GitHub Actions Failures
```bash
# Check logs in GitHub UI:
# Actions → [Failed Workflow] → [Failed Job] → View logs

# Common fixes:
# - Verify all secrets are set
# - Check Terraform state bucket exists
# - Verify AWS credentials have correct permissions
# - Check for resource limits in AWS
```

## Quick URLs

Replace `<EC2_IP>` and `<ACCOUNT_ID>` with your values:

```bash
# Polaris
http://<EC2_IP>:8181/v1/config

# OGC API
http://<EC2_IP>:8080/

# Frontend
http://geospatial-platform-frontend-<ACCOUNT_ID>.s3-website-us-west-2.amazonaws.com

# GitHub Actions
https://github.com/aoneil42/iceberg_test_deployment/actions

# AWS Console - EC2
https://console.aws.amazon.com/ec2/v2/home?region=us-west-2#Instances:

# AWS Console - RDS
https://console.aws.amazon.com/rds/home?region=us-west-2#databases:
```

## Environment Variables

### Required GitHub Secrets
```
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
AWS_ACCOUNT_ID
TERRAFORM_STATE_BUCKET
DB_MASTER_PASSWORD
POLARIS_CLIENT_SECRET
```

### Generate Random Secrets
```bash
# DB Password (24 chars)
openssl rand -base64 24

# Polaris Secret (32 chars)
openssl rand -base64 32

# Strong password (alphanumeric)
openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 24
```

## Cost Monitoring

### Check Current Costs
```bash
# Use AWS Cost Explorer or:
aws ce get-cost-and-usage \
  --time-period Start=2024-10-01,End=2024-10-31 \
  --granularity MONTHLY \
  --metrics "BlendedCost" \
  --group-by Type=SERVICE
```

### Estimate Monthly (8h/day)
- EC2 t4g.medium: ~$8/mo
- RDS db.t4g.micro: ~$3/mo
- S3: ~$2.50/mo
- Other: ~$4/mo
- **Total: ~$17.50/mo**

### Stop Everything to Save Money
```bash
# Via GitHub Actions
gh workflow run start-stop.yml -f action=stop

# Or manually
aws ec2 stop-instances --instance-ids <instance-id>

# Note: RDS continues to incur charges even when not in use
# Consider snapshot + delete for extended downtime
```

## Backup and Recovery

### Create RDS Snapshot
```bash
aws rds create-db-snapshot \
  --db-instance-identifier geospatial-platform-polaris-db \
  --db-snapshot-identifier backup-$(date +%Y%m%d-%H%M%S)
```

### Restore from Snapshot
```bash
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier geospatial-platform-polaris-db-restored \
  --db-snapshot-identifier backup-20241028-120000
```

### Export Polaris Data
```bash
# SSH to EC2
ssh ec2-user@<EC2_IP>

# Dump PostgreSQL database
pg_dump -h <rds-endpoint> -U polaris -d polaris > polaris_backup.sql

# Copy to local
scp ec2-user@<EC2_IP>:polaris_backup.sql .
```

---

**Tip:** Bookmark this page for quick reference!
