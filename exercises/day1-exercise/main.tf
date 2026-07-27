terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = "eu-central-1"
  profile = "hackathon"
}

# Exercise 1 — S3 bucket
resource "aws_s3_bucket" "my_first_bucket" {
  bucket_prefix = "hackathon-${replace(lower(var.owner), " ", "-")}-"

  tags = {
    Project = "knowledge-base"
    Owner   = var.owner
  }
}

# Exercise 2 — encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "my_first_bucket" {
  bucket = aws_s3_bucket.my_first_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Exercise 2 — public access block
resource "aws_s3_bucket_public_access_block" "my_first_bucket" {
  bucket = aws_s3_bucket.my_first_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

variable "owner" {
  description = "Your name (used in bucket naming, lowercase-hyphenated)"
  type        = string
}

output "bucket_name" {
  description = "The name of the bucket that was created"
  value       = aws_s3_bucket.my_first_bucket.id
}

output "bucket_arn" {
  description = "ARN of the bucket"
  value       = aws_s3_bucket.my_first_bucket.arn
}
