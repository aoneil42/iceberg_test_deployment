resource "aws_instance" "geospatial" {
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = var.instance_type
  key_name      = var.key_name

  vpc_security_group_ids = [
    aws_security_group.geospatial.id
  ]

  iam_instance_profile = aws_iam_instance_profile.geospatial.name

  user_data = templatefile("${path.module}/user_data.sh", {
    # PostgreSQL/RDS configuration
    db_host              = aws_db_instance.polaris.address
    db_port              = aws_db_instance.polaris.port
    db_name              = aws_db_instance.polaris.db_name
    db_username          = aws_db_instance.polaris.username
    db_password          = var.db_master_password
    
    # Polaris configuration
    polaris_client_id     = "default-client"
    polaris_client_secret = var.polaris_client_secret
    
    # AWS configuration
    aws_region           = var.aws_region
    ecr_registry         = aws_ecr_repository.polaris.repository_url
    s3_warehouse_bucket  = aws_s3_bucket.warehouse.id
  })

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 30
    delete_on_termination = true
    encrypted             = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = {
    Name        = "geospatial-platform"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }

  lifecycle {
    ignore_changes = [
      ami,
      user_data
    ]
  }
}

# Data source for Amazon Linux 2023 ARM64 AMI
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-6.1-arm64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["arm64"]
  }
}

# Elastic IP for consistent addressing
resource "aws_eip" "geospatial" {
  instance = aws_instance.geospatial.id
  domain   = "vpc"

  tags = {
    Name        = "geospatial-platform-eip"
    Environment = var.environment
  }
}
