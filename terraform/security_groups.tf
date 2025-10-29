# Security group for EC2 instance
resource "aws_security_group" "geospatial" {
  name_prefix = "${var.project_name}-ec2-"
  description = "Security group for geospatial platform EC2 instance"
  vpc_id      = aws_vpc.main.id

  # SSH access (using inline rules for list support)
  dynamic "ingress" {
    for_each = var.allowed_ssh_cidr
    content {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
      description = "SSH from ${ingress.value}"
    }
  }

  # Polaris API access
  dynamic "ingress" {
    for_each = var.allowed_api_cidr
    content {
      from_port   = 8181
      to_port     = 8181
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
      description = "Polaris from ${ingress.value}"
    }
  }

  # OGC API access
  dynamic "ingress" {
    for_each = var.allowed_api_cidr
    content {
      from_port   = 8080
      to_port     = 8080
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
      description = "OGC API from ${ingress.value}"
    }
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-ec2-sg"
      Environment = var.environment
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Note: RDS security group is defined in rds.tf (line 60)
# to keep RDS-related resources together
