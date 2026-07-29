# =============================================================================
# Team 1 — Foundation / Ingestion (Milestone 0)
# =============================================================================
# Owns: S3, Lambda, API Gateway, Bedrock KB, DynamoDB, EventBridge, SES

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
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
# Presigned URL Generator
# -----------------------------------------------------------------------------
module "presigned_url_lambda" {
  source = "../modules/presigned-url-lambda"

  landing_bucket_id            = module.storage.landing_bucket_id
  landing_bucket_arn           = module.storage.landing_bucket_arn
  subnet_ids                   = local.private_subnet_ids
  security_group_id            = local.lambda_security_group_id
  presigned_url_expiry_minutes = 30

  project_name = var.project_name
  environment  = var.environment
}

# -----------------------------------------------------------------------------
# Ingest Lambda (landing → processed bucket)
# -----------------------------------------------------------------------------
module "ingest_lambda" {
  source = "../modules/ingest-lambda"

  landing_bucket_id    = module.storage.landing_bucket_id
  landing_bucket_arn   = module.storage.landing_bucket_arn
  processed_bucket_id  = module.storage.processed_bucket_id
  processed_bucket_arn = module.storage.processed_bucket_arn
  subnet_ids           = local.private_subnet_ids
  security_group_id    = local.lambda_security_group_id
  kb_id                = module.bedrock_kb.knowledge_base_id
  kb_data_source_id    = module.bedrock_kb.data_source_id

  project_name = var.project_name
  environment  = var.environment
}

# -----------------------------------------------------------------------------
# Bedrock Knowledge Base
# -----------------------------------------------------------------------------
module "bedrock_kb" {
  source = "../modules/bedrock-kb"

  processed_bucket_id  = module.storage.processed_bucket_id
  processed_bucket_arn = module.storage.processed_bucket_arn
  region               = var.region

  project_name = var.project_name
  environment  = var.environment
}

# -----------------------------------------------------------------------------
# Audit Lambda (document-audit-trail)
# -----------------------------------------------------------------------------
module "audit_lambda" {
  source = "../modules/audit-lambda"

  processed_bucket_id  = module.storage.processed_bucket_id
  processed_bucket_arn = module.storage.processed_bucket_arn
  audit_table_name     = module.storage.upload_audit_table_name
  audit_table_arn      = module.storage.upload_audit_table_arn
  subnet_ids           = local.private_subnet_ids
  security_group_id    = local.lambda_security_group_id

  project_name = var.project_name
  environment  = var.environment
}

# -----------------------------------------------------------------------------
# Weekly Digest Lambda
# -----------------------------------------------------------------------------
module "digest_lambda" {
  source = "../modules/digest-lambda"

  audit_table_name = module.storage.upload_audit_table_name
  audit_table_arn  = module.storage.upload_audit_table_arn
  sender_email     = "nicolas.schmid@accenture.com"

  project_name = var.project_name
  environment  = var.environment
}

# -----------------------------------------------------------------------------
# TODO: Add these resources during the hackathon
# -----------------------------------------------------------------------------
# - API Gateway: HTTP API for upload endpoint (POST /upload → presigned_url_lambda)
# - Bedrock Knowledge Base + data source (done)
# - EventBridge: weekly schedule rule
# - Lambda: weekly digest generator
# - SES: email identity + sending configuration
# - CloudWatch: dashboards + alarms

# change to test ci again