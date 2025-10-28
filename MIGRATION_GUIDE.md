# Deployment Migration Guide: DynamoDB → RDS PostgreSQL

This guide shows all the changes needed to migrate your iceberg_test_deployment from DynamoDB to RDS PostgreSQL.

## Summary of Changes

### ✅ What's New
- **RDS PostgreSQL** for Polaris metadata (replaces DynamoDB)
- **Coordinated start/stop** via GitHub Actions
- **Official Polaris configuration** per documentation
- **IAM user** for GitHub Actions automation
- **Updated documentation** (no more GitLab references)

### ❌ What's Removed
- DynamoDB tables (dynamodb.tf)
- GitLab CI/CD references
- Manual docker-compose configuration

### 💰 Cost Impact
- **Before**: ~$15-20/month (EC2 only, DynamoDB didn't work)
- **After**: ~$10-40/month depending on usage (EC2 + RDS, fully functional)

---

## Step-by-Step Migration

### 1. Backup Current State (If Deployed)

```bash
cd terraform
terraform show > backup-terraform-state.txt
```

### 2. Delete Old Files

```bash
# Remove DynamoDB configuration
rm terraform/dynamodb.tf

# Remove old security groups (if exists)
rm terraform/sg.tf  # Only if you have duplicate with security_groups.tf
```

### 3. Create New Terraform Files

**File: `terraform/rds.tf`**
```hcl
[Contents from /tmp/terraform_rds.tf]
```

**File: `terraform/variables.tf` (REPLACE existing)**
```hcl
[Contents from /tmp/terraform_variables.tf]
```

**File: `terraform/iam.tf` (REPLACE existing)**
```hcl
[Contents from /tmp/terraform_iam.tf]
```

**File: `terraform/outputs.tf` (REPLACE existing)**
```hcl
[Contents from /tmp/terraform_outputs.tf]
```

### 4. Update EC2 User Data

**File: `terraform/ec2.tf`**

Update the user_data section to use the new template:

```hcl
resource "aws_instance" "geospatial_platform" {
  # ... existing configuration ...
  
  user_data = templatefile("${path.module}/user_data.sh", {
    aws_region           = var.aws_region
    rds_instance_id      = aws_db_instance.polaris.identifier
    db_name              = aws_db_instance.polaris.db_name
    db_username          = var.db_master_username
    db_password          = var.db_master_password
    polaris_image        = "${aws_ecr_repository.polaris.repository_url}:latest"
    ogc_api_image        = "${aws_ecr_repository.ogc_api.repository_url}:latest"
    s3_warehouse_bucket  = aws_s3_bucket.warehouse.id
    ecr_registry         = split("/", aws_ecr_repository.polaris.repository_url)[0]
    docker_compose_content = file("${path.module}/../docker/docker-compose.yml")
  })
  
  # ... rest of configuration ...
}
```

**File: `terraform/user_data.sh` (CREATE)**
```bash
[Contents from /tmp/user_data.sh]
```

### 5. Update Docker Configuration

**File: `docker/docker-compose.yml` (REPLACE existing)**
```yaml
[Contents from /tmp/docker-compose.yml]
```

### 6. Create GitHub Actions Workflows

**File: `.github/workflows/start-infrastructure.yml` (CREATE)**
```yaml
[Contents from /tmp/start-infrastructure.yml]
```

**File: `.github/workflows/stop-infrastructure.yml` (CREATE)**
```yaml
[Contents from /tmp/stop-infrastructure.yml]
```

**File: `.github/workflows/deploy.yml` (REPLACE existing if exists)**
```yaml
[Contents from /tmp/deploy.yml]
```

### 7. Update README

**File: `README.md` (REPLACE existing)**
```markdown
[Contents from /tmp/README.md]
```

### 8. Configure GitHub Secrets

Go to your GitHub repository → Settings → Secrets and variables → Actions

Add these secrets:
```
AWS_ACCESS_KEY_ID=<from Terraform output after first deploy>
AWS_SECRET_ACCESS_KEY=<from Terraform output after first deploy>
DB_MASTER_PASSWORD=<create a secure password>
```

**Generate a secure password:**
```bash
openssl rand -base64 32
```

### 9. Initial Deployment

```bash
# 1. Initialize Terraform with new configuration
cd terraform
terraform init -reconfigure

# 2. Plan the deployment (set DB password)
export TF_VAR_db_master_password="your-secure-password"
terraform plan

# 3. Apply the changes
terraform apply

# 4. Get outputs including GitHub Actions credentials
terraform output -json > outputs.json

# 5. Extract GitHub Actions credentials
cat outputs.json | jq -r '.github_actions_access_key_id.value'
cat outputs.json | jq -r '.github_actions_secret_access_key.value'

# 6. Add these to GitHub Secrets (see step 8)
```

### 10. Verify Deployment

```bash
# Get EC2 public IP
EC2_IP=$(terraform output -raw ec2_public_ip)

# Wait 5 minutes for services to start, then test:
curl http://$EC2_IP:8182/q/health

# Should return: {"status":"UP","checks":[...]}
```

### 11. Get Polaris Root Credentials

```bash
# SSH to EC2
aws ssm start-session --target <instance-id>

# View Polaris logs to get root credentials
docker logs polaris-catalog 2>&1 | grep "root principal credentials"

# Save these credentials - you'll need them to create catalogs!
```

---

## Testing the New Setup

### Start/Stop Workflow Test

1. **Stop infrastructure:**
   - Go to Actions → Stop Infrastructure → Run workflow
   - Wait ~2 minutes
   - Verify both EC2 and RDS are stopped in AWS Console

2. **Start infrastructure:**
   - Go to Actions → Start Infrastructure → Run workflow  
   - Wait ~10 minutes (RDS takes time to start)
   - Test endpoints work

### Create a Test Catalog

```bash
# Use the root credentials from step 11
CLIENT_ID="<from-polaris-logs>"
CLIENT_SECRET="<from-polaris-logs>"

# Create a catalog
curl -X POST "http://$EC2_IP:8181/api/v1/catalogs" \
  -u "$CLIENT_ID:$CLIENT_SECRET" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "test_catalog",
    "type": "INTERNAL",
    "properties": {
      "default-base-location": "s3://your-warehouse-bucket/test/"
    },
    "storageConfigInfo": {
      "storageType": "S3",
      "allowedLocations": ["s3://your-warehouse-bucket/"]
    }
  }'
```

---

## Rollback Plan (If Needed)

If something goes wrong:

```bash
# 1. Destroy new infrastructure
cd terraform
terraform destroy

# 2. Restore from backup
git checkout <previous-commit>

# 3. Restore old Terraform state if needed
# (You saved this in step 1)
```

---

## Key Differences: Old vs New

| Aspect | Old (DynamoDB) | New (RDS) |
|--------|----------------|-----------|
| **Metadata Store** | DynamoDB | PostgreSQL RDS |
| **Polaris Config** | Custom/broken | Official documentation |
| **Start/Stop** | Manual EC2 only | Automated EC2 + RDS |
| **Cost (5 days)** | N/A (didn't work) | ~$10/month |
| **CI/CD** | GitLab | GitHub Actions |
| **Bootstrap** | None | Automatic on first start |

---

## Common Issues & Solutions

### Issue: Terraform can't create RDS subnet group
**Solution:** You need at least 2 subnets in different AZs. The new `rds.tf` creates this automatically.

### Issue: Polaris returns 404
**Solution:** Check that RDS is running and accessible from EC2. Review security group rules.

### Issue: GitHub Actions can't start RDS
**Solution:** Verify AWS credentials in GitHub Secrets have RDS permissions.

### Issue: Docker containers can't connect to RDS
**Solution:** Check that security group allows traffic from EC2 security group to RDS on port 5432.

---

## Post-Migration Checklist

- [ ] All Terraform files updated
- [ ] GitHub Secrets configured
- [ ] Infrastructure deployed successfully
- [ ] Polaris responding to health checks
- [ ] Root credentials saved securely
- [ ] Test catalog created successfully
- [ ] Start/Stop workflows tested
- [ ] Documentation updated
- [ ] Old DynamoDB resources cleaned up

---

## Next Steps

1. **Load some test data** using the ETL scripts
2. **Test OGC API Features** endpoint
3. **Configure deck.gl frontend** with your EC2 IP
4. **Set up monitoring** (CloudWatch alarms)
5. **Implement authentication** for production use

---

## Support

If you encounter issues:
1. Check CloudWatch Logs: `/aws/ec2/iceberg-test`
2. Review Polaris logs: `docker logs polaris-catalog`
3. Check RDS connectivity: `nc -zv <RDS_ENDPOINT> 5432`
4. Open a GitHub issue with logs and error messages

Good luck with your migration! 🚀
