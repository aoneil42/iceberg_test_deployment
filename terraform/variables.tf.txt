variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-west-2"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "geospatial-platform"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "eval"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t4g.medium"
}

variable "volume_size" {
  description = "EBS volume size in GB"
  type        = number
  default     = 30
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed for SSH access"
  type        = string
  default     = "0.0.0.0/0" # Replace with your IP/32 in production
}

variable "allowed_api_cidr" {
  description = "CIDR block allowed for API access"
  type        = string
  default     = "0.0.0.0/0"
}

variable "key_name" {
  description = "EC2 key pair name for SSH access"
  type        = string
  default     = "" # Leave empty to create instance without key pair
}