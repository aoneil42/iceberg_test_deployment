# ECR Repositories for Docker images
# Note: ECR repositories are now managed by GitHub Actions workflow
# They are created automatically in the build-images job before pushing
# This prevents the chicken-and-egg problem and allows for better CI/CD control

# Commenting out to avoid conflict with workflow-managed repos
# If you want Terraform to manage them, import them first:
# terraform import aws_ecr_repository.polaris polaris
# terraform import aws_ecr_repository.ogc_api ogc-api

# resource "aws_ecr_repository" "polaris" {
#   name                 = "polaris"
#   image_tag_mutability = "MUTABLE"
# 
#   image_scanning_configuration {
#     scan_on_push = true
#   }
# 
#   tags = {
#     Name        = "Polaris Catalog"
#     Project     = "Iceberg Geospatial Platform"
#     Environment = var.environment
#   }
# }
# 
# resource "aws_ecr_repository" "ogc_api" {
#   name                 = "ogc-api"
#   image_tag_mutability = "MUTABLE"
# 
#   image_scanning_configuration {
#     scan_on_push = true
#   }
# 
#   tags = {
#     Name        = "OGC API Features"
#     Project     = "Iceberg Geospatial Platform"
#     Environment = var.environment
#   }
# }

# Lifecycle policy to keep only last 10 images
# Commented out since ECR repos are managed by workflow
# resource "aws_ecr_lifecycle_policy" "polaris" {
#   repository = aws_ecr_repository.polaris.name
# 
#   policy = jsonencode({
#     rules = [{
#       rulePriority = 1
#       description  = "Keep last 10 images"
#       selection = {
#         tagStatus   = "any"
#         countType   = "imageCountMoreThan"
#         countNumber = 10
#       }
#       action = {
#         type = "expire"
#       }
#     }]
#   })
# }
# 
# resource "aws_ecr_lifecycle_policy" "ogc_api" {
#   repository = aws_ecr_repository.ogc_api.name
# 
#   policy = jsonencode({
#     rules = [{
#       rulePriority = 1
#       description  = "Keep last 10 images"
#       selection = {
#         tagStatus   = "any"
#         countType   = "imageCountMoreThan"
#         countNumber = 10
#       }
#       action = {
#         type = "expire"
#       }
#     }]
#   })
# }
# 
# # Outputs
# # Note: Can't output ECR URLs since repos are managed outside Terraform
# # Get URLs manually: aws ecr describe-repositories --region us-west-2
# 
# # output "polaris_ecr_url" {
# #   description = "ECR repository URL for Polaris"
# #   value       = aws_ecr_repository.polaris.repository_url
# # }
# # 
# # output "ogc_api_ecr_url" {
# #   description = "ECR repository URL for OGC API"
# #   value       = aws_ecr_repository.ogc_api.repository_url
# # }
