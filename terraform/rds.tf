# RDS PostgreSQL for Polaris Metadata Store
resource "aws_db_subnet_group" "polaris" {
  name       = "${var.project_name}-polaris-subnet-group"
  subnet_ids = [aws_subnet.main.id, aws_subnet.secondary.id]

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-polaris-subnet-group"
    }
  )
}

resource "aws_db_instance" "polaris" {
  identifier     = "${var.project_name}-polaris-db"
  engine         = "postgres"
  engine_version = "16.6"
  
  instance_class    = "db.t4g.micro"
  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true
  
  db_name  = "polaris"
  username = var.db_master_username
  password = var.db_master_password
  
  db_subnet_group_name   = aws_db_subnet_group.polaris.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  
  publicly_accessible = false
  
  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "mon:04:00-mon:05:00"
  
  skip_final_snapshot       = true
  final_snapshot_identifier = "${var.project_name}-polaris-final-snapshot-${random_id.suffix.hex}"
  
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  
  # Allow stopping for cost savings
  deletion_protection = false
  
  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-polaris-db"
    }
  )
}

# Security group for RDS
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg-${random_id.suffix.hex}"
  description = "Security group for Polaris RDS PostgreSQL"
  vpc_id      = aws_vpc.main.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-rds-sg"
    }
  )
}

# Allow PostgreSQL access from EC2 security group
resource "aws_vpc_security_group_ingress_rule" "rds_from_ec2" {
  security_group_id = aws_security_group.rds.id
  description       = "PostgreSQL from EC2"

  referenced_security_group_id = aws_security_group.geospatial_platform.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"

  tags = {
    Name = "PostgreSQL from EC2"
  }
}

# Allow all outbound traffic from RDS (for updates, etc.)
resource "aws_vpc_security_group_egress_rule" "rds_all_outbound" {
  security_group_id = aws_security_group.rds.id
  description       = "Allow all outbound traffic"

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"

  tags = {
    Name = "All outbound"
  }
}

# Create secondary subnet in different AZ for RDS subnet group requirement
resource "aws_subnet" "secondary" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-subnet-secondary"
    }
  )
}

# Associate secondary subnet with route table
resource "aws_route_table_association" "secondary" {
  subnet_id      = aws_subnet.secondary.id
  route_table_id = aws_route_table.main.id
}

# Data source to get available AZs
data "aws_availability_zones" "available" {
  state = "available"
}
