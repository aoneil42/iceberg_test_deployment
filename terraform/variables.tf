variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "geospatial-platform"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t4g.medium"
}

variable "key_name" {
  description = "SSH key pair name (optional)"
  type        = string
  default     = ""
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH to EC2 instance"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Change this to your IP!
}

variable "allowed_api_cidr" {
  description = "CIDR block allowed to access API endpoints"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# PostgreSQL/RDS Configuration
variable "db_master_password" {
  description = "Master password for RDS PostgreSQL"
  type        = string
  sensitive   = true
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t4g.micro"
}

variable "db_allocated_storage" {
  description = "Allocated storage for RDS in GB"
  type        = number
  default     = 20
}

variable "db_backup_retention_period" {
  description = "Number of days to retain automated backups"
  type        = number
  default     = 7
}

variable "db_multi_az" {
  description = "Enable Multi-AZ deployment for RDS"
  type        = bool
  default     = false
}

# Polaris Configuration
variable "polaris_client_secret" {
  description = "Polaris OAuth client secret"
  type        = string
  sensitive   = true
}

# S3 Configuration
variable "s3_versioning_enabled" {
  description = "Enable S3 versioning for warehouse bucket"
  type        = bool
  default     = true
}

# Tags
variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}
}
