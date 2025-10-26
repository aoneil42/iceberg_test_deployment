resource "aws_security_group" "geospatial_platform" {
  name        = "${var.project_name}-sg-${random_id.suffix.hex}"
  description = "Security group for geospatial platform EC2 instance"
  vpc_id      = data.aws_vpc.default.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-sg"
    }
  )
}

# SSH access
resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.geospatial_platform.id

  description = "SSH access"
  from_port   = 22
  to_port     = 22
  ip_protocol = "tcp"
  cidr_ipv4   = var.allowed_ssh_cidr

  tags = {
    Name = "ssh-access"
  }
}

# Polaris REST catalog
resource "aws_vpc_security_group_ingress_rule" "polaris" {
  security_group_id = aws_security_group.geospatial_platform.id

  description = "Polaris catalog API"
  from_port   = 8181
  to_port     = 8181
  ip_protocol = "tcp"
  cidr_ipv4   = var.allowed_api_cidr

  tags = {
    Name = "polaris-api"
  }
}

# OGC API Features
resource "aws_vpc_security_group_ingress_rule" "ogc_api" {
  security_group_id = aws_security_group.geospatial_platform.id

  description = "OGC API Features"
  from_port   = 8080
  to_port     = 8080
  ip_protocol = "tcp"
  cidr_ipv4   = var.allowed_api_cidr

  tags = {
    Name = "ogc-api"
  }
}

# HTTPS (for future ALB)
resource "aws_vpc_security_group_ingress_rule" "https" {
  security_group_id = aws_security_group.geospatial_platform.id

  description = "HTTPS access"
  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0"

  tags = {
    Name = "https-access"
  }
}

# Allow all outbound traffic
resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.geospatial_platform.id

  description = "Allow all outbound traffic"
  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"

  tags = {
    Name = "all-outbound"
  }
}