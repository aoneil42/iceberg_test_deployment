# ECR Repositories for Docker images

resource "aws_ecr_repository" "polaris" {
  name                 = "polaris-catalog"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "Polaris Catalog"
    Project     = "Iceberg Geospatial Platform"
    Environment = var.environment
  }
}

resource "aws_ecr_repository" "ogc_api" {
  name                 = "ogc-api-features"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "OGC API Features"
    Project     = "Iceberg Geospatial Platform"
    Environment = var.environment
  }
}

# Lifecycle policy to keep only last 10 images
resource "aws_ecr_lifecycle_policy" "polaris" {
  repository = aws_ecr_repository.polaris.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}

resource "aws_ecr_lifecycle_policy" "ogc_api" {
  repository = aws_ecr_repository.ogc_api.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}

# Outputs
output "polaris_ecr_url" {
  description = "ECR repository URL for Polaris"
  value       = aws_ecr_repository.polaris.repository_url
}

output "ogc_api_ecr_url" {
  description = "ECR repository URL for OGC API"
  value       = aws_ecr_repository.ogc_api.repository_url
}
