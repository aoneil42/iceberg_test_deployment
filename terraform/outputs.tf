output "ec2_instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.geospatial_platform.id
}

output "ec2_public_ip" {
  description = "EC2 public IP address"
  value       = aws_instance.geospatial_platform.public_ip
}

output "ec2_public_dns" {
  description = "EC2 public DNS"
  value       = aws_instance.geospatial_platform.public_dns
}

output "s3_bucket_name" {
  description = "S3 bucket name for data storage"
  value       = aws_s3_bucket.data_warehouse.id
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.data_warehouse.arn
}

output "dynamodb_table_name" {
  description = "DynamoDB table name for Polaris metadata"
  value       = aws_dynamodb_table.polaris_metadata.id
}

output "ecr_polaris_repository_url" {
  description = "ECR repository URL for Polaris"
  value       = aws_ecr_repository.polaris.repository_url
}

output "ecr_ogc_api_repository_url" {
  description = "ECR repository URL for OGC API"
  value       = aws_ecr_repository.ogc_api.repository_url
}

output "polaris_endpoint" {
  description = "Polaris catalog endpoint"
  value       = "http://${aws_instance.geospatial_platform.public_ip}:8181"
}

output "ogc_api_endpoint" {
  description = "OGC API Features endpoint"
  value       = "http://${aws_instance.geospatial_platform.public_ip}:8080"
}

output "ssh_command" {
  description = "SSH command to connect to EC2 instance"
  value       = "ssh ec2-user@${aws_instance.geospatial_platform.public_ip}"
}

output "deployment_info" {
  description = "Deployment information"
  value = {
    region            = var.aws_region
    instance_type     = var.instance_type
    availability_zone = aws_instance.geospatial_platform.availability_zone
  }
}