# EC2 Instance
resource "aws_instance" "geospatial_platform" {
  ami           = data.aws_ami.amazon_linux_2023_arm64.id
  instance_type = var.instance_type
  subnet_id                   = data.aws_subnets.default.ids[0]
  vpc_security_group_ids      = [aws_security_group.geospatial_platform.id]
  iam_instance_profile        = aws_iam_instance_profile.geospatial_platform.name
  associate_public_ip_address = true
  key_name = var.key_name != "" ? var.key_name : null
  
  root_block_device {
    volume_type           = "gp3"
    volume_size           = 30
    delete_on_termination = true
    encrypted             = true
    tags = merge(
      local.common_tags,
      {
        Name = "${var.project_name}-root-volume"
      }
    )
  }
  
  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    # AWS Configuration
    aws_region             = var.aws_region
    
    # RDS PostgreSQL Configuration (Updated for Polaris)
    rds_instance_id        = aws_db_instance.polaris.identifier
    db_host                = aws_db_instance.polaris.address
    db_port                = aws_db_instance.polaris.port
    db_name                = aws_db_instance.polaris.db_name
    db_username            = var.db_master_username
    db_password            = var.db_master_password
    db_endpoint            = aws_db_instance.polaris.endpoint
    
    # Polaris Configuration
    client_secret          = var.client_secret != "" ? var.client_secret : random_password.client_secret[0].result
    polaris_realm          = var.polaris_realm
    
    # Docker Images
    polaris_image          = "${aws_ecr_repository.polaris.repository_url}:latest"
    ogc_api_image          = "${aws_ecr_repository.ogc_api.repository_url}:latest"
    
    # S3 Configuration
    s3_warehouse_bucket    = aws_s3_bucket.data_warehouse.id
    s3_bucket              = aws_s3_bucket.data_warehouse.id
    
    # ECR Configuration
    ecr_registry           = split("/", aws_ecr_repository.polaris.repository_url)[0]
    ecr_polaris_image      = "${aws_ecr_repository.polaris.repository_url}:latest"
    ecr_ogc_api_image      = "${aws_ecr_repository.ogc_api.repository_url}:latest"
    
    # Note: Removed docker_compose_content - will be created directly in user_data.sh
    # This avoids template interpolation issues
  }))
  
  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "enabled"
  }
  
  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-instance"
    }
  )
  
  lifecycle {
    ignore_changes = [ami]
  }
  
  depends_on = [
    aws_db_instance.polaris,
    aws_ecr_repository.polaris,
    aws_ecr_repository.ogc_api,
    aws_s3_bucket.data_warehouse
  ]
}

# Elastic IP for production (optional)
resource "aws_eip" "geospatial_platform" {
  count    = var.environment == "prod" ? 1 : 0
  domain   = "vpc"
  instance = aws_instance.geospatial_platform.id
  
  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-eip"
    }
  )
}

# Generate random client secret if not provided
resource "random_password" "client_secret" {
  count   = var.client_secret == "" ? 1 : 0
  length  = 32
  special = true
}

# Store secrets in AWS Secrets Manager for better security
resource "aws_secretsmanager_secret" "polaris_credentials" {
  name = "${var.project_name}-polaris-credentials-${random_id.suffix.hex}"
  
  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-polaris-credentials"
    }
  )
}

resource "aws_secretsmanager_secret_version" "polaris_credentials" {
  secret_id = aws_secretsmanager_secret.polaris_credentials.id
  secret_string = jsonencode({
    client_id     = "root"
    client_secret = var.client_secret != "" ? var.client_secret : random_password.client_secret[0].result
    db_username   = var.db_master_username
    db_password   = var.db_master_password
    db_endpoint   = aws_db_instance.polaris.endpoint
  })
}
