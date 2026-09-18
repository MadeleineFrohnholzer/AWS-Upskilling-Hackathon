# =============================================================================
# Terraform State Backend (Pre-provision this BEFORE the hackathon)
# =============================================================================
# This creates the S3 bucket and DynamoDB table used for remote state.
# Run this once manually, then all squads use it as their backend.

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = "knowledge-base-hackathon"
      Environment = "shared"
      ManagedBy   = "terraform"
    }
  }
}

# -----------------------------------------------------------------------------
# S3 Bucket for Terraform State
# -----------------------------------------------------------------------------
resource "aws_s3_bucket" "terraform_state" {
  bucket = "hackathon-tf-state-${data.aws_caller_identity.current.account_id}"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket                  = aws_s3_bucket.terraform_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# HTTPS-only access policy
resource "aws_s3_bucket_policy" "terraform_state_https_only" {
  bucket = aws_s3_bucket.terraform_state.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyNonHttpsAccess"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource = [
        aws_s3_bucket.terraform_state.arn,
        "${aws_s3_bucket.terraform_state.arn}/*",
      ]
      Condition = {
        Bool = { "aws:SecureTransport" = "false" }
      }
    }]
  })
  depends_on = [aws_s3_bucket_public_access_block.terraform_state]
}

# -----------------------------------------------------------------------------
# DynamoDB Table for State Locking
# -----------------------------------------------------------------------------
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "hackathon-tf-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

# =============================================================================
# GitHub Actions OIDC — scoped to AccentureCodeFoundry repo
# =============================================================================
# The OIDC provider already exists in the account (created manually).
# Import it once before applying:
#   terraform import aws_iam_openid_connect_provider.github \
#     arn:aws:iam::064453091991:oidc-provider/token.actions.githubusercontent.com

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
  ]
}

resource "aws_iam_role" "github_actions" {
  name = "GitHubActions-aabg-agentic-platform"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:AccentureCodeFoundry/314259_aabg-agentic-platform:*"
        }
      }
    }]
  })
}

# Attach the same policy as the existing GithubActionsHackathon role
resource "aws_iam_role_policy_attachment" "github_actions_terraform" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/TerraformDeployPolicy"
}

output "github_actions_role_arn" {
  description = "Set this as AWS_ROLE_ARN secret in AccentureCodeFoundry/314259_aabg-agentic-platform"
  value       = aws_iam_role.github_actions.arn
}

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------
data "aws_caller_identity" "current" {}
