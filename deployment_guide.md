# Deployment Guide

Complete step-by-step guide for deploying the geospatial platform.

## Prerequisites Checklist

- [ ] AWS Account with admin access
- [ ] AWS CLI installed and configured
- [ ] GitLab account
- [ ] SSH key pair created
- [ ] Domain name (optional)

## Step 1: AWS Setup

### Create SSH Key Pair

```bash
# Generate SSH key
ssh-keygen -t rsa -b 4096 -f ~/.ssh/geospatial-platform

# Import to AWS
aws ec2 import-key-pair \
    --key-name geospatial-platform \
    --public-key-material fileb://~/.ssh/geospatial-platform.pub \
    --region us-west-2
```

### Create Terraform State Bucket

```bash
# Create bucket
aws s3 mb s3://geospatial-platform-tfstate-$(date +%s) --region us-west-2

# Enable versioning
aws s3api put-bucket-versioning \
    --bucket geospatial-platform-tfstate-TIMESTAMP \
    --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
    --bucket geospatial-platform-tfstate-TIMESTAMP \
    --server-side-encryption-configuration '{
        "Rules": [{
            "ApplyServerSideEncryptionByDefault": {
                "SSEAlgorithm": "AES256"
            }
        }]
    }'

# Save bucket name for later
export TF_STATE_BUCKET=geospatial-platform-tfstate-TIMESTAMP
```

## Step 2: GitLab Project Setup

### Create Repository

1. Go to GitLab.com
2. Create new project: `geospatial-platform`
3. Clone repository:

```bash
git clone git@gitlab.com:YOUR_USERNAME/geospatial-platform.git
cd geospatial-platform
```

### Add Project Files

```bash
# Copy all files from the implementation
cp -r /path/to/implementation/* .

git add .
git commit -m "Initial commit"
git push origin main
```

### Configure CI/CD Variables

Go to: Settings → CI/CD → Variables

Add the following variables (all should be **protected** and **masked**):

| Variable | Value | Notes |
|----------|-------|-------|
| `AWS_ACCESS_KEY_ID` | `AKIA...` | From AWS IAM user |
| `AWS_SECRET_ACCESS_KEY` | `xxxxx` | From AWS IAM user |
| `AWS_ACCOUNT_ID` | `123456789012` | Your AWS account ID |
| `AWS_REGION` | `us-west-2` | AWS region |
| `SSH_PRIVATE_KEY` | `-----BEGIN...` | Contents of private key |
| `TERRAFORM_STATE_BUCKET` | `geospatial-...` | From Step 1 |

### Get AWS Account ID

```bash
aws sts get-caller-identity --query Account --output text
```

## Step 3: Configure Terraform

### Update Variables

Edit `terraform/variables.tf`:

```hcl
variable "allowed_ssh_cidr" {
  default     = "YOUR_IP/32"  # Change this!
}

variable "key_name" {
  default     = "geospatial-platform"  # Your key pair name
}
```

### Get Your IP Address

```bash
curl -4 ifconfig.me
# Output: xxx.xxx.xxx.xxx

# Update terraform/variables.tf:
# allowed_ssh_cidr = "xxx.xxx.xxx.xxx/32"
```

### Commit Changes

```bash
git add terraform/variables.tf
git commit -m "Configure SSH access"
git push origin main
```

## Step 4: Initial Deployment

### Trigger Pipeline

1. Go to GitLab: CI/CD → Pipelines
2. Pipeline should start automatically
3. Wait for `validate` and `build` stages to complete

### Deploy Infrastructure

1. Review Terraform plan in pipeline logs
2. Manually trigger `deploy-infra` stage
3. Wait 5-10 minutes for infrastructure creation
4. Check outputs in pipeline artifacts

### Deploy Application

1. Manually trigger `deploy-app` stage
2. Wait 3-5 minutes for containers to start
3. Check health checks pass

### Get EC2 IP Address

```bash
# Download Terraform outputs from GitLab artifacts
# Or run locally:
cd terraform
terraform output ec2_public_ip
```

## Step 5: Verify Deployment

### Test Services

```bash
export EC2_IP=<your-ec2-ip>

# Test Polaris
curl http://$EC2_IP:8181/v1/config

# Test OGC API
curl http://$EC2_IP:8080/
curl http://$EC2_IP:8080/conformance
curl http://$EC2_IP:8080/collections
```

### Check Logs

```bash
ssh ec2-user@$EC2_IP
cd ~/deployment
docker-compose logs -f
```

## Step 6: Load Sample Data

### Prepare Sample GeoJSON

Create `sample_data.geojson`:

```json
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "geometry": {
        "type": "Point",
        "coordinates": [-105.0, 40.0]
      },
      "properties": {
        "name": "Denver",
        "population": 715522
      }
    }
  ]
}
```

### Run ETL

```bash
# Install dependencies
cd etl
pip install -r requirements.txt

# Load data
python examples/sample_load.py \
    --input sample_data.geojson \
    --table cities \
    --polaris-endpoint http://$EC2_IP:8181 \
    --s3-bucket $(terraform -chdir=../terraform output -raw s3_bucket_name)
```

### Verify Data

```bash
# Check table exists
curl http://$EC2_IP:8080/collections

# Query features
curl "http://$EC2_IP:8080/collections/cities/items?limit=10"
```

## Step 7: Setup Frontend

### Option A: Local Development

```bash
cd frontend
npm install
npm run dev
```

Open http://localhost:5173 and enter: `http://$EC2_IP:8080`

### Option B: Deploy to S3

```bash
cd frontend
npm install
npm run build

# Create S3 bucket for static hosting
aws s3 mb s3://geospatial-platform-frontend-$(date +%s)
aws s3 website s3://geospatial-platform-frontend-... \
    --index-document index.html

# Upload files
aws s3 sync dist/ s3://geospatial-platform-frontend-.../

# Make public
aws s3api put-bucket-policy \
    --bucket geospatial-platform-frontend-... \
    --policy '{
        "Version": "2012-10-17",
        "Statement": [{
            "Sid": "PublicRead",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::geospatial-platform-frontend-.../*"
        }]
    }'
```

## Step 8: Production Hardening (Optional)

### Enable HTTPS

```bash
# Request ACM certificate
aws acm request-certificate \
    --domain-name api.yourdomain.com \
    --validation-method DNS

# Create Application Load Balancer
# Update security groups
# Configure ALB target group to EC2 instance
```

### Restrict Access

Update `terraform/variables.tf`:

```hcl
variable "allowed_ssh_cidr" {
  default = "YOUR_OFFICE_IP/32"
}

variable "allowed_api_cidr" {
  default = "YOUR_OFFICE_IP/32"
}
```

### Enable Backups

```bash
# S3 versioning (already enabled)

# DynamoDB point-in-time recovery
aws dynamodb update-continuous-backups \
    --table-name $(terraform output -raw dynamodb_table_name) \
    --point-in-time-recovery-specification PointInTimeRecoveryEnabled=true

# EC2 AMI snapshot
aws ec2 create-image \
    --instance-id $(terraform output -raw ec2_instance_id) \
    --name "geospatial-platform-backup-$(date +%Y%m%d)"
```

## Step 9: Monitoring Setup

### CloudWatch Alarms

```bash
# CPU utilization alarm
aws cloudwatch put-metric-alarm \
    --alarm-name geospatial-platform-high-cpu \
    --alarm-description "Alert on high CPU" \
    --metric-name CPUUtilization \
    --namespace AWS/EC2 \
    --statistic Average \
    --period 300 \
    --threshold 80 \
    --comparison-operator GreaterThanThreshold \
    --dimensions Name=InstanceId,Value=$(terraform output -raw ec2_instance_id) \
    --evaluation-periods 2

# Disk space alarm
aws cloudwatch put-metric-alarm \
    --alarm-name geospatial-platform-low-disk \
    --metric-name disk_used_percent \
    --namespace CWAgent \
    --statistic Average \
    --period 300 \
    --threshold 85 \
    --comparison-operator GreaterThanThreshold \
    --dimensions Name=InstanceId,Value=$(terraform output -raw ec2_instance_id) \
    --evaluation-periods 1
```

### Log Groups

```bash
# Create log group
aws logs create-log-group \
    --log-group-name /geospatial-platform/application

# Set retention
aws logs put-retention-policy \
    --log-group-name /geospatial-platform/application \
    --retention-in-days 7
```

## Step 10: Cost Optimization

### Setup Budgets

```bash
aws budgets create-budget \
    --account-id $(aws sts get-caller-identity --query Account --output text) \
    --budget '{
        "BudgetName": "geospatial-platform-monthly",
        "BudgetLimit": {
            "Amount": "50",
            "Unit": "USD"
        },
        "TimeUnit": "MONTHLY",
        "BudgetType": "COST"
    }'
```

### Scheduled Start/Stop

Create EventBridge rule:

```bash
# Stop at 6 PM weekdays
aws events put-rule \
    --name stop-geospatial-platform \
    --schedule-expression "cron(0 18 ? * MON-FRI *)"

# Start at 8 AM weekdays
aws events put-rule \
    --name start-geospatial-platform \
    --schedule-expression "cron(0 8 ? * MON-FRI *)"

# Add targets (requires Lambda function)
```

## Troubleshooting

### Pipeline Fails at Build Stage

**Issue**: ECR authentication fails

**Solution**:
```bash
# Verify AWS credentials
aws sts get-caller-identity

# Check ECR repository exists
aws ecr describe-repositories
```

### Cannot Connect to EC2

**Issue**: SSH connection refused

**Solution**:
```bash
# Check security group
aws ec2 describe-security-groups \
    --filters Name=tag:Name,Values=geospatial-platform-sg

# Verify your current IP
curl ifconfig.me

# Update security group if needed
```

### Services Not Starting

**Issue**: Docker containers fail to start

**Solution**:
```bash
ssh ec2-user@$EC2_IP

# Check user data execution
cat /var/log/user_data.log

# Check Docker
sudo systemctl status docker

# Check containers
cd ~/deployment
docker-compose ps
docker-compose logs
```

### ETL Fails

**Issue**: Cannot connect to Polaris

**Solution**:
```bash
# Test Polaris from EC2
ssh ec2-user@$EC2_IP
curl http://localhost:8181/v1/config

# Test from local
curl http://$EC2_IP:8181/v1/config

# Check security group allows port 8181
```

## Next Steps

1. ✅ Load production data
2. ✅ Configure domain name and HTTPS
3. ✅ Setup monitoring and alerting
4. ✅ Implement backup strategy
5. ✅ Document operational procedures
6. ✅ Train team on platform usage

## Support Resources

- **AWS Support**: https://console.aws.amazon.com/support
- **GitLab Support**: https://about.gitlab.com/support/
- **Project Documentation**: README.md
- **API Documentation**: http://$EC2_IP:8080/api/docs

---

**Deployment Complete! 🎉**

Your geospatial platform is now running at:
- **Polaris Catalog**: http://$EC2_IP:8181
- **OGC API**: http://$EC2_IP:8080
- **Frontend**: http://localhost:5173 (dev) or S3 URL