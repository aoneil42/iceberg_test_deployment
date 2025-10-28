# Deployment Checklist

Use this checklist to track your migration progress.

## Pre-Migration

- [ ] Backup current `.gitlab-ci.yml` (just in case)
- [ ] Review MIGRATION_GUIDE.md completely
- [ ] Have AWS credentials ready
- [ ] Have GitHub account access

## Setup GitHub Secrets

Go to: Your Repo → Settings → Secrets and variables → Actions → New repository secret

- [ ] `AWS_ACCESS_KEY_ID` - Your AWS access key
- [ ] `AWS_SECRET_ACCESS_KEY` - Your AWS secret key  
- [ ] `AWS_ACCOUNT_ID` - Your 12-digit AWS account ID
- [ ] `TERRAFORM_STATE_BUCKET` - S3 bucket name for Terraform state
- [ ] `DB_MASTER_PASSWORD` - Generate with: `openssl rand -base64 24`
- [ ] `POLARIS_CLIENT_SECRET` - Generate with: `openssl rand -base64 32`

## Prepare AWS Resources

- [ ] Create Terraform state bucket:
  ```bash
  aws s3 mb s3://your-terraform-state-bucket --region us-west-2
  aws s3api put-bucket-versioning \
    --bucket your-terraform-state-bucket \
    --versioning-configuration Status=Enabled
  ```

## Copy Files to Repository

- [ ] Copy `.github/workflows/` directory
- [ ] Copy updated `terraform/ec2.tf`
- [ ] Copy updated `terraform/user_data.sh`
- [ ] Copy updated `terraform/variables.tf`
- [ ] Copy new `terraform/s3_frontend.tf`
- [ ] Copy updated `docker/polaris/Dockerfile`
- [ ] Copy new `docker/polaris/entrypoint.sh`
- [ ] Copy `frontend/package.json`
- [ ] Copy `frontend/vite.config.js`

## Update Existing Files

- [ ] Update `terraform/rds.tf` (verify it's correct)
- [ ] Update `terraform/security_groups.tf` (add RDS security group)
- [ ] Update `terraform/outputs.tf` (add RDS and frontend outputs)
- [ ] Remove or backup `.gitlab-ci.yml`
- [ ] Remove `terraform/dynamodb.tf` (if it exists)

## Install Dependencies

- [ ] Install frontend dependencies:
  ```bash
  cd frontend
  npm install
  cd ..
  ```

## Terraform Format

- [ ] Run `terraform fmt -recursive` in terraform directory
- [ ] Commit formatting changes

## Git Workflow

- [ ] Create feature branch: `git checkout -b refactor/rds-and-github-actions`
- [ ] Stage all changes: `git add .`
- [ ] Commit: `git commit -m "Refactor: Switch to RDS PostgreSQL and GitHub Actions"`
- [ ] Push: `git push origin refactor/rds-and-github-actions`
- [ ] Create Pull Request on GitHub
- [ ] Review changes in PR
- [ ] Merge to main

## Deployment

- [ ] Watch GitHub Actions workflow start automatically
- [ ] Monitor deployment progress in Actions tab
- [ ] Wait for "Deploy Geospatial Platform" workflow to complete (~10-15 min)

## Verification

- [ ] Get EC2 IP from workflow output or `terraform output`
- [ ] Test Polaris: `curl http://<EC2_IP>:8181/v1/config`
- [ ] Test OGC API: `curl http://<EC2_IP>:8080/`
- [ ] Access frontend URL (shown in workflow output)
- [ ] Check S3 bucket has frontend files

## Post-Deployment

- [ ] Review CloudWatch logs for any errors
- [ ] SSH to EC2 and check Docker containers: `docker-compose ps`
- [ ] Verify RDS is running in AWS Console
- [ ] Test loading sample data
- [ ] Update repository README with new architecture

## Optional: Setup Start/Stop Automation

- [ ] Review `.github/workflows/start-stop.yml` schedule
- [ ] Adjust schedule if needed (default: 8 AM - 6 PM EST, Mon-Fri)
- [ ] Test manual start: Actions → Start/Stop EC2 → Run workflow → start
- [ ] Test manual stop: Actions → Start/Stop EC2 → Run workflow → stop
- [ ] Verify status: Actions → Start/Stop EC2 → Run workflow → status

## Troubleshooting (If Needed)

If deployment fails:

- [ ] Check GitHub Actions logs for errors
- [ ] Verify all secrets are set correctly
- [ ] Check CloudWatch Logs in AWS Console
- [ ] Verify Terraform state bucket exists and is accessible
- [ ] Review MIGRATION_GUIDE.md troubleshooting section
- [ ] SSH to EC2: `ssh ec2-user@<EC2_IP>`
- [ ] Check Docker logs: `docker-compose logs`

## Rollback (If Necessary)

- [ ] Revert commit: `git revert HEAD`
- [ ] Or hard reset: `git reset --hard <previous-commit>`
- [ ] Destroy infrastructure: `cd terraform && terraform destroy`
- [ ] Restore GitLab CI if needed

## Success Criteria

✅ All checks passed when:
- GitHub Actions workflow completes successfully
- Polaris responds at port 8181
- OGC API responds at port 8080
- Frontend loads in browser
- RDS instance is running and Polaris can connect
- No errors in CloudWatch Logs
- Docker containers are healthy

---

## Notes

Use this space for any notes during migration:

```
[Your notes here]
```

---

## Timeline Estimate

- Setup (secrets, dependencies): 15 minutes
- File updates: 20 minutes  
- First deployment: 10-15 minutes
- Verification: 10 minutes
- **Total: ~60 minutes**

---

**Last updated:** [Add date when you start]
**Started by:** [Your name]
**Status:** [ ] Not Started / [ ] In Progress / [ ] Completed
