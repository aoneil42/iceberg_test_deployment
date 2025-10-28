output "ec2_instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.geospatial_platform.id
}

output "ec2_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.geospatial_platform.public_ip
}

output "polaris_endpoint" {
  description = "Polaris catalog endpoint"
  value       = "http://${aws_instance.geospatial_platform.public_ip}:8181"
}

output "ogc_api_endpoint" {
  description = "OGC API Features endpoint"
  value       = "http://${aws_instance.geospatial_platform.public_ip}:8080"
}

output "s3_warehouse_bucket" {
  description = "S3 bucket for Iceberg warehouse"
  value       = aws_s3_bucket.warehouse.id
}

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint for Polaris"
  value       = aws_db_instance.polaris.endpoint
}

output "rds_instance_id" {
  description = "RDS instance identifier"
  value       = aws_db_instance.polaris.identifier
}

output "rds_database_name" {
  description = "RDS database name"
  value       = aws_db_instance.polaris.db_name
}

output "ecr_repository_urls" {
  description = "ECR repository URLs"
  value = {
    polaris = aws_ecr_repository.polaris.repository_url
    ogc_api = aws_ecr_repository.ogc_api.repository_url
  }
}

output "github_actions_access_key_id" {
  description = "Access key ID for GitHub Actions (add to GitHub secrets)"
  value       = aws_iam_access_key.github_actions.id
  sensitive   = true
}

output "github_actions_secret_access_key" {
  description = "Secret access key for GitHub Actions (add to GitHub secrets)"
  value       = aws_iam_access_key.github_actions.secret
  sensitive   = true
}

output "deployment_commands" {
  description = "Commands to deploy the application"
  value = <<-EOT
    # Connect to EC2 via Session Manager (no SSH key needed):
    aws ssm start-session --target ${aws_instance.geospatial_platform.id}
    
    # Or via SSH (if key_name was provided):
    ssh ec2-user@${aws_instance.geospatial_platform.public_ip}
    
    # Access endpoints:
    Polaris: http://${aws_instance.geospatial_platform.public_ip}:8181/v1/config
    OGC API: http://${aws_instance.geospatial_platform.public_ip}:8080/
    
    # RDS Connection String:
    postgresql://${var.db_master_username}:${nonsensitive(var.db_master_password)}@${aws_db_instance.polaris.endpoint}/${aws_db_instance.polaris.db_name}
  EOT
}
