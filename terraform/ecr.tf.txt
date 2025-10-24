resource "aws_ecr_repository" "polaris" {
  name                 = "polaris-catalog"
  image_tag_mutability = "MUTABLE"
  
  image_scanning_configuration {
    scan_on_push = true
  }
  
  encryption_configuration {
    encryption_type = "AES256"
  }
  
  tags = merge(
    local.common_tags,
    {
      Name = "polaris-catalog"
    }
  )
}

resource "aws_ecr_repository" "ogc_api" {
  name                 = "ogc-api-features"
  image_tag_mutability = "MUTABLE"
  
  image_scanning_configuration {
    scan_on_push = true
  }
  
  encryption_configuration {
    encryption_type = "AES256"
  }
  
  tags = merge(
    local.common_tags,
    {
      Name = "ogc-api-features"
    }
  )
}

# Lifecycle policy for Polaris repository
resource "aws_ecr_lifecycle_policy" "polaris" {
  repository = aws_ecr_repository.polaris.name
  
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 5 images"
        selection = {
          tagStatus     = "any"
          countType     = "imageCountMoreThan"
          countNumber   = 5
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# Lifecycle policy for OGC API repository
resource "aws_ecr_lifecycle_policy" "ogc_api" {
  repository = aws_ecr_repository.ogc_api.name
  
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 5 images"
        selection = {
          tagStatus     = "any"
          countType     = "imageCountMoreThan"
          countNumber   = 5
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}