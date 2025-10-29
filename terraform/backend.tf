# terraform/backend.tf
terraform {
  backend "s3" {
    bucket  = "geospatial-platform-tfstate-1761510504"
    key     = "iceberg-test-deployment/terraform.tfstate"
    region  = "us-west-2"
    encrypt = true
  }
}