# =============================================================================
# Team 1 — Foundation / Ingestion (Milestone 0)
# =============================================================================
# Owns: S3, Lambda, API Gateway, Bedrock KB, DynamoDB, EventBridge, SES

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "hackathon-tf-state-064453091991"
    key            = "team1/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "hackathon-tf-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      Team        = "team1-ingestion"
      ManagedBy   = "terraform"
    }
  }
}

# -----------------------------------------------------------------------------
# Read shared infrastructure outputs
# -----------------------------------------------------------------------------
data "terraform_remote_state" "shared" {
  backend = "s3"
  config = {
    bucket = "hackathon-tf-state-064453091991"
    key    = "shared/terraform.tfstate"
    region = "eu-central-1"
  }
}

# Convenience locals from shared state
locals {
  vpc_id                   = data.terraform_remote_state.shared.outputs.vpc_id
  private_subnet_ids       = data.terraform_remote_state.shared.outputs.private_subnet_ids
  lambda_security_group_id = data.terraform_remote_state.shared.outputs.lambda_security_group_id
}

# -----------------------------------------------------------------------------
# Storage Module (S3 + DynamoDB)
# -----------------------------------------------------------------------------
module "storage" {
  source = "../modules/storage"

  project_name = var.project_name
  environment  = var.environment
}

# -----------------------------------------------------------------------------
# TODO: Add these resources during the hackathon
# -----------------------------------------------------------------------------
# - Lambda: presigned URL generator
# - Lambda: metadata sidecar creator
# - Lambda: S3 event trigger handler
# - API Gateway: REST API for upload endpoints
# - Bedrock Knowledge Base + data source
# - EventBridge: weekly schedule rule
# - Lambda: weekly digest generator
# - SES: email identity + sending configuration
# - CloudWatch: dashboards + alarms
