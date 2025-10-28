resource "aws_s3_bucket" "data_warehouse" {
  bucket = local.bucket_name

  force_destroy = true  # Add this line

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-warehouse"
    }
  )
}

resource "aws_s3_bucket_versioning" "data_warehouse" {
  bucket = aws_s3_bucket.data_warehouse.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "data_warehouse" {
  bucket = aws_s3_bucket.data_warehouse.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data_warehouse" {
  bucket = aws_s3_bucket.data_warehouse.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "data_warehouse" {
  bucket = aws_s3_bucket.data_warehouse.id

  rule {
    id     = "delete-old-iceberg-snapshots"
    status = "Enabled"

    filter {
      prefix = "warehouse/"
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  rule {
    id     = "transition-polaris-metadata"
    status = "Enabled"

    filter {
      prefix = "polaris-metadata/"
    }

    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }
  }
}

resource "aws_s3_bucket_cors_configuration" "data_warehouse" {
  bucket = aws_s3_bucket.data_warehouse.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag", "Content-Length", "Content-Type"]
    max_age_seconds = 3600
  }
}

# Create initial folder structure
resource "aws_s3_object" "polaris_metadata" {
  bucket  = aws_s3_bucket.data_warehouse.id
  key     = "polaris-metadata/"
  content = ""

  tags = local.common_tags
}

resource "aws_s3_object" "warehouse" {
  bucket  = aws_s3_bucket.data_warehouse.id
  key     = "warehouse/"
  content = ""

  tags = local.common_tags
}

resource "aws_s3_object" "warehouse_default" {
  bucket  = aws_s3_bucket.data_warehouse.id
  key     = "warehouse/default/"
  content = ""

  tags = local.common_tags
}