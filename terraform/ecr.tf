# ECR Repositories for Docker images
# Note: ECR repositories are managed by GitHub Actions workflow
# They are created automatically in the build-images job before pushing
# We use data sources to query the existing repositories

# Query existing ECR repositories (created by workflow)
data "aws_ecr_repository" "polaris" {
  name = "polaris"
}

data "aws_ecr_repository" "ogc_api" {
  name = "ogc-api"
}

# Outputs
output "polaris_ecr_url" {
  description = "ECR repository URL for Polaris"
  value       = data.aws_ecr_repository.polaris.repository_url
}

output "ogc_api_ecr_url" {
  description = "ECR repository URL for OGC API"
  value       = data.aws_ecr_repository.ogc_api.repository_url
}
