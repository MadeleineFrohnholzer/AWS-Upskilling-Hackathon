# =============================================================================
# Team 2 - Access / Knowledge App (Milestone 1)
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
# Bedrock Agent (grounded retrieval with inline citations)
# -----------------------------------------------------------------------------
module "bedrock_agent" {
  source = "../modules/bedrock-agent"

  project_name       = var.project_name
  environment        = var.environment
  knowledge_base_id  = var.knowledge_base_id
  knowledge_base_arn = var.knowledge_base_arn
}

# -----------------------------------------------------------------------------
# Bedrock Proxy ECR repository
# -----------------------------------------------------------------------------
module "bedrock_proxy" {
  source = "../modules/bedrock-proxy"

  project_name = var.project_name
  environment  = var.environment
}

# -----------------------------------------------------------------------------
# Compute Module (ECS, ECR, ALB target group attachment)
# -----------------------------------------------------------------------------
module "compute" {
  source = "../modules/compute"

  project_name           = var.project_name
  environment            = var.environment
  vpc_id                 = local.vpc_id
  private_subnet_ids     = local.private_subnet_ids
  container_image        = var.open_webui_image
  proxy_image            = var.proxy_image
  bedrock_agent_id       = module.bedrock_agent.agent_id
  bedrock_agent_alias_id = module.bedrock_agent.agent_alias_id
}

# -----------------------------------------------------------------------------
# Cognito User Pool + Entra ID SSO Federation
# -----------------------------------------------------------------------------
resource "aws_cognito_user_pool" "main" {
  name = "${var.project_name}-${var.environment}-user-pool"

  admin_create_user_config {
    allow_admin_create_user_only = true
  }

  password_policy {
    minimum_length                   = 12
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = true
    require_uppercase                = true
    temporary_password_validity_days = 1
  }
}

# Cognito hosted-UI domain (used by ALB for the OAuth redirect)
resource "aws_cognito_user_pool_domain" "main" {
  domain       = "${var.project_name}-${var.environment}"
  user_pool_id = aws_cognito_user_pool.main.id
}

# Entra ID OIDC identity provider
resource "aws_cognito_identity_provider" "entra_id" {
  user_pool_id  = aws_cognito_user_pool.main.id
  provider_name = "EntraID"
  provider_type = "OIDC"

  provider_details = {
    oidc_issuer               = "https://login.microsoftonline.com/${var.entra_tenant_id}/v2.0"
    client_id                 = var.entra_client_id
    client_secret             = var.entra_client_secret
    authorize_scopes          = "openid email profile"
    attributes_request_method = "GET"
    authorize_url             = "https://login.microsoftonline.com/${var.entra_tenant_id}/oauth2/v2.0/authorize"
    token_url                 = "https://login.microsoftonline.com/${var.entra_tenant_id}/oauth2/v2.0/token"
    attributes_url            = "https://graph.microsoft.com/oidc/userinfo"
    jwks_uri                  = "https://login.microsoftonline.com/${var.entra_tenant_id}/discovery/v2.0/keys"
  }

  attribute_mapping = {
    email    = "email"
    username = "sub"
    name     = "name"
  }
}

resource "aws_cognito_user_pool_client" "chat_app" {
  name         = "${var.project_name}-${var.environment}-chat-app-client"
  user_pool_id = aws_cognito_user_pool.main.id

  generate_secret                      = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["openid", "email", "profile"]
  allowed_oauth_flows_user_pool_client = true
  supported_identity_providers         = ["EntraID"]

  callback_urls = var.cognito_callback_urls
  logout_urls   = var.cognito_logout_urls

  access_token_validity  = 1
  id_token_validity      = 1
  refresh_token_validity = 1

  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }

  depends_on = [aws_cognito_identity_provider.entra_id]
}

# -----------------------------------------------------------------------------
# ALB Target Group + Cognito Listener Rule (issue #36)
# -----------------------------------------------------------------------------
resource "aws_lb_target_group" "chat_frontend" {
  name        = "${var.project_name}-chat-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = local.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = "/health"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }
}

# authenticate-cognito must be the first action; forward must be second
resource "aws_lb_listener_rule" "chat_frontend" {
  listener_arn = local.alb_listener_arn
  priority     = 100

  action {
    type = "authenticate-cognito"
    authenticate_cognito {
      user_pool_arn              = aws_cognito_user_pool.main.arn
      user_pool_client_id        = aws_cognito_user_pool_client.chat_app.id
      user_pool_domain           = aws_cognito_user_pool_domain.main.domain
      on_unauthenticated_request = "authenticate"
      session_cookie_name        = "AWSELBAuthSessionCookie"
      session_timeout            = 28800
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.chat_frontend.arn
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }
}

# -----------------------------------------------------------------------------
# TODO: Add these resources during the hackathon
# -----------------------------------------------------------------------------
# - ECS Fargate service (register tasks into chat_frontend target group)