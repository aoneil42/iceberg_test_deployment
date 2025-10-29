output "ec2_instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.geospatial.id
}

output "ec2_public_ip" {
  description = "EC2 public IP address"
  value       = aws_eip.geospatial.public_ip
}

output "instance_id" {
  description = "EC2 instance ID (for start/stop workflows)"
  value       = aws_instance.geospatial.id
}

output "polaris_endpoint" {
  description = "Polaris catalog endpoint"
  value       = "http://${aws_eip.geospatial.public_ip}:8181"
}

output "ogc_api_endpoint" {
  description = "OGC API Features endpoint"
  value       = "http://${aws_eip.geospatial.public_ip}:8080"
}

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = aws_db_instance.polaris.endpoint
}

output "rds_address" {
  description = "RDS PostgreSQL address (hostname only)"
  value       = aws_db_instance.polaris.address
}

output "warehouse_bucket" {
  description = "S3 warehouse bucket name"
  value       = aws_s3_bucket.warehouse.id
}

output "frontend_bucket" {
  description = "Frontend S3 bucket name"
  value       = aws_s3_bucket.frontend.id
}

output "frontend_url" {
  description = "Frontend S3 website URL"
  value       = "http://${aws_s3_bucket.frontend.bucket}.s3-website-${var.aws_region}.amazonaws.com"
}
