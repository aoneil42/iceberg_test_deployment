variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "iceberg-test"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t4g.medium"
}

variable "key_name" {
  description = "Name of the SSH key pair (optional - will use Session Manager if not provided)"
  type        = string
  default     = ""
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH to EC2 (leave empty to disable SSH)"
  type        = string
  default     = ""
}

variable "allowed_api_cidr" {
  description = "CIDR blocks allowed to access API endpoints (comma-separated)"
  type        = string
  default     = "0.0.0.0/0"
}

variable "s3_bucket_prefix" {
  description = "Prefix for S3 bucket name (will be suffixed with random ID)"
  type        = string
  default     = "iceberg-test-warehouse"
}

variable "db_master_username" {
  description = "Master username for RDS PostgreSQL"
  type        = string
  default     = "polaris_admin"
  sensitive   = true
}

variable "db_master_password" {
  description = "Master password for RDS PostgreSQL (use GitHub Actions secret)"
  type        = string
  sensitive   = true
}

variable "enable_cloudwatch_logs" {
  description = "Enable CloudWatch logs for EC2 and containers"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
