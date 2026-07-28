# =============================================================================
# Team 2 — Access / Knowledge App (Milestone 1)
# =============================================================================
# Owns: Cognito, ECS Fargate, ECR, Bedrock Agent, ALB target groups

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
    key            = "team2/terraform.tfstate"
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
      Team        = "team2-app"
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

# Read Team 1 outputs (for Bedrock KB ID)
data "terraform_remote_state" "team1" {
  backend = "s3"
  config = {
    bucket = "hackathon-tf-state-064453091991"
    key    = "team1/terraform.tfstate"
    region = "eu-central-1"
  }
}

# Convenience locals from shared/team1 state
locals {
  vpc_id                      = data.terraform_remote_state.shared.outputs.vpc_id
  private_subnet_ids          = data.terraform_remote_state.shared.outputs.private_subnet_ids
  alb_arn                     = data.terraform_remote_state.shared.outputs.alb_arn
  alb_listener_arn            = data.terraform_remote_state.shared.outputs.alb_listener_arn
  ecs_tasks_security_group_id = data.terraform_remote_state.shared.outputs.ecs_tasks_security_group_id
  # bedrock_kb_id             = data.terraform_remote_state.team1.outputs.bedrock_kb_id  # uncomment when Team 1 has KB ready
}

# -----------------------------------------------------------------------------
# Compute Module (ECS, ECR, ALB target group attachment)
# -----------------------------------------------------------------------------
module "compute" {
  source = "../modules/compute"

  project_name       = var.project_name
  environment        = var.environment
  vpc_id             = local.vpc_id
  private_subnet_ids = local.private_subnet_ids
}

# -----------------------------------------------------------------------------
# TODO: Add these resources during the hackathon
# -----------------------------------------------------------------------------
# - Cognito User Pool + Entra ID federation
# - ALB target group + attach ECS service
# - ALB listener rule (forward to target group)
# - Bedrock Agent definition + tool-use schema
# - Agent action group pointing to Team 1's KB
# - HTTPS listener (needs ACM cert or use HTTP for hackathon)
