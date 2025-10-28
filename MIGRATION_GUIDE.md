# Geospatial Platform Refactoring Guide

## Overview

This refactoring accomplishes two major goals:
1. **Switch from DynamoDB to RDS PostgreSQL** for Apache Polaris catalog metadata
2. **Migrate from GitLab CI/CD to GitHub Actions** with integrated frontend build

## What Changed

### Architecture Changes

**Before:**
```
deck.gl → OGC API (8080) → Polaris (8181) → DynamoDB + S3
```

**After:**
```
deck.gl → OGC API (8080) → Polaris (8181) → RDS PostgreSQL + S3
```

### Key Benefits

1. **RDS PostgreSQL:**
   - ✅ Officially supported by Apache Polaris documentation
   - ✅ ACID compliance with full transaction support
   - ✅ Better query performance for catalog operations
   - ✅ Automated backups and point-in-time recovery
   - ✅ Similar cost (~$8-10/month for db.t4g.micro)

2. **GitHub Actions:**
   - ✅ Native GitHub integration
   - ✅ No external CI/CD service needed
   - ✅ Built-in secrets management
   - ✅ Scheduled start/stop for cost savings
   - ✅ Frontend build automated in pipeline

3. **Frontend CI/CD Integration:**
   - ✅ Automatic build on every commit
   - ✅ Deploy to S3 static website
   - ✅ No manual frontend deployment needed

## Files Changed

### New Files

```
.github/
├── workflows/
│   ├── deploy.yml           # Main deployment pipeline
│   └── start-stop.yml       # Scheduled EC2 start/stop

frontend/
├── package.json             # Build configuration
└── vite.config.js          # Vite bundler config

terraform/
└── s3_frontend.tf          # S3 bucket for frontend hosting
```

### Modified Files

```
terraform/
├── ec2.tf                  # Updated to use RDS variables
├── user_data.sh            # PostgreSQL configuration
└── variables.tf            # Added db_master_password

docker/
└── polaris/
    ├── Dockerfile          # Added PostgreSQL client
    └── entrypoint.sh       # Wait for RDS and configure
```

### Removed Files

```
.gitlab-ci.yml              # Replaced by GitHub Actions
terraform/dynamodb.tf       # Replaced by rds.tf (existing)
```

## Migration Steps

### Step 1: Prepare Your Repository

```bash
# Clone your repository
git clone https://github.com/aoneil42/iceberg_test_deployment.git
cd iceberg_test_deployment

# Create a new branch for the refactoring
git checkout -b refactor/rds-and-github-actions
```

### Step 2: Copy Updated Files

Copy all files from this refactoring package to your repository:

```bash
# Copy GitHub Actions workflows
cp -r refactor/.github .

# Copy updated Terraform files
cp refactor/terraform/ec2.tf terraform/
cp refactor/terraform/user_data.sh terraform/
cp refactor/terraform/variables.tf terraform/
cp refactor/terraform/s3_frontend.tf terraform/

# Copy updated Docker files
cp refactor/docker/polaris/Dockerfile docker/polaris/
cp refactor/docker/polaris/entrypoint.sh docker/polaris/

# Copy frontend build configuration
cp refactor/frontend/package.json frontend/
cp refactor/frontend/vite.config.js frontend/

# Remove GitLab CI (keep as backup if needed)
git mv .gitlab-ci.yml .gitlab-ci.yml.backup

# Remove DynamoDB Terraform (if exists)
git rm terraform/dynamodb.tf || true
```

### Step 3: Update Your Existing Files

#### A. Update `terraform/rds.tf`

You already have this file, but ensure it looks like this:

```hcl
resource "aws_db_instance" "polaris" {
  identifier        = "${var.project_name}-polaris-db"
  engine            = "postgres"
  engine_version    = "16.1"
  instance_class    = var.db_instance_class
  allocated_storage = var.db_allocated_storage

  db_name  = "polaris"
  username = "polaris"
  password = var.db_master_password

  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.polaris.name

  backup_retention_period = var.db_backup_retention_period
  backup_window          = "03:00-04:00"
  maintenance_window     = "mon:04:00-mon:05:00"

  multi_az               = var.db_multi_az
  storage_encrypted      = true
  skip_final_snapshot    = true

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-polaris-db"
      Environment = var.environment
    }
  )
}
```

#### B. Update `terraform/security_groups.tf`

Add RDS security group:

```hcl
resource "aws_security_group" "rds" {
  name_prefix = "${var.project_name}-rds-"
  description = "Security group for Polaris RDS PostgreSQL"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.geospatial.id]
    description     = "PostgreSQL from EC2"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-rds-sg"
      Environment = var.environment
    }
  )
}
```

#### C. Update `terraform/outputs.tf`

Add RDS outputs:

```hcl
output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = aws_db_instance.polaris.endpoint
}

output "frontend_url" {
  description = "Frontend S3 website URL"
  value       = "http://${aws_s3_bucket.frontend.bucket}.s3-website-${var.aws_region}.amazonaws.com"
}
```

### Step 4: Set Up GitHub Secrets

Go to your GitHub repository → Settings → Secrets and variables → Actions

Add the following secrets:

```
AWS_ACCESS_KEY_ID          # Your AWS access key
AWS_SECRET_ACCESS_KEY      # Your AWS secret key
AWS_ACCOUNT_ID             # Your AWS account ID
TERRAFORM_STATE_BUCKET     # S3 bucket for Terraform state
DB_MASTER_PASSWORD         # PostgreSQL master password (min 8 chars)
POLARIS_CLIENT_SECRET      # Polaris OAuth secret (generate random string)
```

Generate secrets:

```bash
# Generate Polaris client secret
openssl rand -base64 32

# Generate DB password
openssl rand -base64 24
```

### Step 5: Create Terraform State Bucket (if not exists)

```bash
# Set your AWS profile or credentials
export AWS_PROFILE=your-profile

# Create S3 bucket for Terraform state
aws s3 mb s3://your-terraform-state-bucket --region us-west-2

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket your-terraform-state-bucket \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket your-terraform-state-bucket \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'
```

### Step 6: Install Frontend Dependencies

```bash
cd frontend
npm install
cd ..
```

### Step 7: Commit and Push

```bash
git add .
git commit -m "Refactor: Switch to RDS PostgreSQL and GitHub Actions

- Replace DynamoDB with RDS PostgreSQL for Polaris metadata
- Migrate from GitLab CI to GitHub Actions
- Integrate frontend build into CI/CD pipeline
- Add automated EC2 start/stop workflows
"

git push origin refactor/rds-and-github-actions
```

### Step 8: Deploy

1. **Create Pull Request:**
   - Go to GitHub and create a PR from your branch
   - Review the changes
   - Merge to main

2. **First Deployment:**
   - GitHub Actions will automatically trigger
   - Watch the workflow: Actions → Deploy Geospatial Platform
   - This will:
     - Validate Terraform
     - Build frontend
     - Build and push Docker images to ECR
     - Deploy infrastructure (including RDS)
     - Deploy application

3. **Monitor Deployment:**
   - Check the Actions tab for progress
   - Deployment takes ~10-15 minutes (RDS creation is slowest)

### Step 9: Verify Deployment

After deployment completes:

```bash
# Get the EC2 IP from GitHub Actions output or:
cd terraform
terraform output ec2_public_ip

# Test endpoints
curl http://<EC2_IP>:8181/v1/config        # Polaris
curl http://<EC2_IP>:8080/                 # OGC API

# Check frontend
# URL will be in GitHub Actions output
```

## Cost Comparison

### Before (DynamoDB)

| Service | Monthly Cost |
|---------|-------------|
| EC2 t4g.medium (8h/day) | $8 |
| DynamoDB | $1 |
| S3 (100GB) | $2.30 |
| Other | $4 |
| **Total** | **~$15.30** |

### After (RDS PostgreSQL)

| Service | Monthly Cost |
|---------|-------------|
| EC2 t4g.medium (8h/day) | $8 |
| RDS db.t4g.micro (8h/day) | $3 |
| S3 (100GB + frontend) | $2.50 |
| Other | $4 |
| **Total** | **~$17.50** |

**Additional cost: $2.20/month** for significant benefits of PostgreSQL.

## Using Start/Stop Workflows

Save money by stopping EC2 when not in use:

### Automatic (Scheduled)

The workflow is configured to:
- **Start:** 8 AM EST, Monday-Friday
- **Stop:** 6 PM EST, Monday-Friday

Edit `.github/workflows/start-stop.yml` to change schedule.

### Manual Control

```bash
# Via GitHub UI:
# Actions → Start/Stop EC2 Instance → Run workflow
# Select: start, stop, or status

# Via GitHub CLI:
gh workflow run start-stop.yml -f action=start
gh workflow run start-stop.yml -f action=stop
gh workflow run start-stop.yml -f action=status
```

## Troubleshooting

### 1. RDS Connection Timeout

```bash
# Check security group rules
aws ec2 describe-security-groups --group-ids <rds-sg-id>

# Verify RDS is running
aws rds describe-db-instances --db-instance-identifier geospatial-platform-polaris-db
```

### 2. Polaris Won't Start

```bash
# SSH to EC2
ssh ec2-user@<EC2_IP>

# Check logs
cd ~/deployment
docker-compose logs polaris

# Check PostgreSQL connectivity
PGPASSWORD='your-password' psql -h <rds-endpoint> -U polaris -d polaris
```

### 3. Frontend Build Fails

```bash
# Check Node.js version (need 18+)
node --version

# Clean install
cd frontend
rm -rf node_modules package-lock.json
npm install
npm run build
```

### 4. GitHub Actions Fails

- Check secrets are set correctly
- Verify AWS credentials have necessary permissions
- Review CloudWatch logs for EC2 instance
- Check Terraform state bucket exists

## Rollback Plan

If something goes wrong:

```bash
# 1. Revert to previous commit
git revert HEAD

# 2. Or restore from backup
git checkout main
git reset --hard <previous-commit-sha>
git push origin main --force

# 3. Destroy new infrastructure
cd terraform
terraform destroy -auto-approve

# 4. Restore GitLab CI
git mv .gitlab-ci.yml.backup .gitlab-ci.yml
git commit -m "Rollback to GitLab CI"
git push origin main
```

## Next Steps

After successful migration:

1. **Update Documentation:**
   - Update README with new architecture
   - Document new deployment process
   - Add RDS backup/restore procedures

2. **Security Hardening:**
   - Restrict security group CIDR blocks
   - Enable RDS encryption at rest (already done)
   - Set up CloudWatch alarms

3. **Monitoring:**
   - Create CloudWatch dashboard
   - Set up RDS performance insights
   - Monitor PostgreSQL slow query log

4. **Optimization:**
   - Tune PostgreSQL parameters
   - Consider RDS Multi-AZ for production
   - Set up automated RDS snapshots

## Support

If you encounter issues:

1. Check GitHub Actions logs
2. Review CloudWatch Logs
3. Verify all secrets are set
4. Ensure Terraform state bucket exists
5. Check AWS service quotas

## References

- [Apache Polaris Documentation](https://polaris.apache.org/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [AWS RDS PostgreSQL](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_PostgreSQL.html)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
