# Bootstrap: create S3 state buckets and DynamoDB lock tables per environment (us-east-2).
# Run once with: terraform init && terraform apply
# Then configure each environment's backend.tf to use the outputs below.

locals {
  envs = toset(["dev", "nonprod", "prod"])
}

# S3 buckets for Terraform state (versioning + encryption)
resource "aws_s3_bucket" "state" {
  for_each = local.envs

  bucket = "${var.bucket_prefix}-tfstate-${each.key}"

  tags = {
    Name        = "${var.bucket_prefix}-tfstate-${each.key}"
    Environment = each.key
    Purpose     = "terraform-state"
  }
}

resource "aws_s3_bucket_versioning" "state" {
  for_each = local.envs

  bucket = aws_s3_bucket.state[each.key].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  for_each = local.envs

  bucket = aws_s3_bucket.state[each.key].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "state" {
  for_each = local.envs

  bucket = aws_s3_bucket.state[each.key].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB tables for state locking
resource "aws_dynamodb_table" "lock" {
  for_each = local.envs

  name         = "${var.bucket_prefix}-tfstate-${each.key}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "${var.bucket_prefix}-tfstate-${each.key}"
    Environment = each.key
    Purpose     = "terraform-state-lock"
  }
}
