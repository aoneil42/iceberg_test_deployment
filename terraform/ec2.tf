resource "aws_instance" "geospatial_platform" {
  ami           = data.aws_ami.amazon_linux_2023_arm64.id
  instance_type = var.instance_type

  subnet_id                   = data.aws_subnets.default.ids[0]
  vpc_security_group_ids      = [aws_security_group.geospatial_platform.id]
  iam_instance_profile        = aws_iam_instance_profile.geospatial_platform.name
  associate_public_ip_address = true

  key_name = var.key_name != "" ? var.key_name : null

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.volume_size
    delete_on_termination = true
    encrypted             = true

    tags = merge(
      local.common_tags,
      {
        Name = "${var.project_name}-root-volume"
      }
    )
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    aws_region     = var.aws_region
    s3_bucket      = local.bucket_name
    dynamodb_table = local.dynamodb_table
    ecr_registry   = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
  }))

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-instance"
    }
  )

  lifecycle {
    ignore_changes = [ami]
  }
}

resource "aws_eip" "geospatial_platform" {
  count    = var.environment == "prod" ? 1 : 0
  domain   = "vpc"
  instance = aws_instance.geospatial_platform.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-eip"
    }
  )
}