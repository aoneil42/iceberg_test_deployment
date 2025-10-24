resource "aws_dynamodb_table" "polaris_metadata" {
  name           = local.dynamodb_table
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "catalog_id"
  range_key      = "entity_type"
  
  attribute {
    name = "catalog_id"
    type = "S"
  }
  
  attribute {
    name = "entity_type"
    type = "S"
  }
  
  attribute {
    name = "namespace"
    type = "S"
  }
  
  attribute {
    name = "table_name"
    type = "S"
  }
  
  global_secondary_index {
    name            = "namespace-index"
    hash_key        = "namespace"
    range_key       = "table_name"
    projection_type = "ALL"
  }
  
  point_in_time_recovery {
    enabled = false # Set to true for production
  }
  
  server_side_encryption {
    enabled = true
  }
  
  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-polaris-metadata"
    }
  )
}

# DynamoDB table for Polaris backend store
resource "aws_dynamodb_table" "polaris_backend" {
  name           = "${local.dynamodb_table}-backend"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "identifier"
  range_key      = "version"
  
  attribute {
    name = "identifier"
    type = "S"
  }
  
  attribute {
    name = "version"
    type = "N"
  }
  
  point_in_time_recovery {
    enabled = false
  }
  
  server_side_encryption {
    enabled = true
  }
  
  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-polaris-backend"
    }
  )
}