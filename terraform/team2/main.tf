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

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Convenience locals from shared/team1 state
locals {
  vpc_id                      = data.terraform_remote_state.shared.outputs.vpc_id
  private_subnet_ids          = data.terraform_remote_state.shared.outputs.private_subnet_ids
  alb_arn                     = data.terraform_remote_state.shared.outputs.alb_arn
  alb_listener_arn            = data.terraform_remote_state.shared.outputs.alb_listener_arn
  ecs_tasks_security_group_id = data.terraform_remote_state.shared.outputs.ecs_tasks_security_group_id
  account_id                  = data.aws_caller_identity.current.account_id
  region                      = data.aws_region.current.region
  container_image             = var.open_webui_image != "" ? var.open_webui_image : "${module.compute.ecr_repository_url}:latest"
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
  alb_arn                = local.alb_arn
  container_image        = var.open_webui_image
  proxy_image            = var.proxy_image
  bedrock_agent_id       = module.bedrock_agent.agent_id
  bedrock_agent_alias_id = module.bedrock_agent.agent_alias_id
  ecs_service_name       = "${var.project_name}-open-webui"
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

# Entra ID OIDC identity provider — only created when secrets are configured.
# Set ENTRA_TENANT_ID, ENTRA_CLIENT_ID, ENTRA_CLIENT_SECRET in GitHub Actions secrets.
resource "aws_cognito_identity_provider" "entra_id" {
  count = var.entra_tenant_id != "" ? 1 : 0

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

  generate_secret = true

  allowed_oauth_flows_user_pool_client = length(compact(var.cognito_callback_urls)) > 0
  allowed_oauth_flows                  = length(compact(var.cognito_callback_urls)) > 0 ? ["code"] : []
  allowed_oauth_scopes                 = length(compact(var.cognito_callback_urls)) > 0 ? ["openid", "email", "profile"] : []
  supported_identity_providers = var.entra_tenant_id != "" ? ["EntraID"] : ["COGNITO"]

  callback_urls = compact(var.cognito_callback_urls)
  logout_urls   = compact(var.cognito_logout_urls)

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
# ECS Fargate Service behind Internal ALB (issue #39)
# -----------------------------------------------------------------------------

# SSM SecureString for Open WebUI session-signing key (min 32 chars)
resource "aws_ssm_parameter" "webui_secret_key" {
  name  = "/${var.project_name}/open-webui/secret-key"
  type  = "SecureString"
  value = "REPLACE_ME_AFTER_FIRST_DEPLOY_MIN_32_CHARS_LONG"

  lifecycle {
    ignore_changes = [value]
  }
}

# Execution role policy - allows pulling SSM SecureString at task startup
resource "aws_iam_role_policy" "ecs_task_execution_ssm" {
  name = "ssm-secret-read"
  role = module.compute.ecs_task_execution_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "SSMSecretRead"
      Effect   = "Allow"
      Action   = ["ssm:GetParameter", "ssm:GetParameters"]
      Resource = aws_ssm_parameter.webui_secret_key.arn
    }]
  })
}

# Task role - runtime AWS API calls from inside the container (named platform-*)
resource "aws_iam_role" "ecs_task" {
  name = "platform-${var.project_name}-open-webui-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "ecs_task" {
  name = "open-webui-bedrock-ssm"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "BedrockAgentInvoke"
        Effect = "Allow"
        Action = [
          "bedrock-agent-runtime:InvokeAgent",
          "bedrock-agent-runtime:Retrieve",
          "bedrock-agent-runtime:RetrieveAndGenerate",
        ]
        Resource = [
          "arn:aws:bedrock:${local.region}:${local.account_id}:agent/${var.bedrock_agent_id}",
          "arn:aws:bedrock:${local.region}:${local.account_id}:agent-alias/${var.bedrock_agent_id}/*",
          "arn:aws:bedrock:${local.region}:${local.account_id}:knowledge-base/${var.bedrock_kb_id}",
        ]
      },
      {
        Sid      = "SSMRead"
        Effect   = "Allow"
        Action   = ["ssm:GetParameter"]
        Resource = aws_ssm_parameter.webui_secret_key.arn
      }
    ]
  })
}

# CloudWatch log group for Open WebUI
resource "aws_cloudwatch_log_group" "open_webui" {
  name              = "/ecs/${var.project_name}-open-webui"
  retention_in_days = 14
}

# -----------------------------------------------------------------------------
# ALB Target Group + Cognito Listener Rule (issue #36)
# -----------------------------------------------------------------------------

# ALB target group - ip type required for Fargate awsvpc networking
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

# ECS task definition - Open WebUI with Bedrock Agent env vars
resource "aws_ecs_task_definition" "open_webui" {
  family                   = "${var.project_name}-open-webui"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = module.compute.ecs_task_execution_role_arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name         = "open-webui"
    image        = local.container_image
    portMappings = [{ containerPort = 8080, protocol = "tcp" }]
    environment = [
      { name = "WEBUI_AUTH", value = "true" },
      { name = "ENABLE_SIGNUP", value = "false" },
      { name = "DEFAULT_USER_ROLE", value = "user" },
      { name = "AWS_REGION", value = local.region },
      { name = "BEDROCK_AGENT_ID", value = var.bedrock_agent_id },
      { name = "BEDROCK_AGENT_ALIAS_ID", value = var.bedrock_agent_alias_id },
      { name = "KNOWLEDGE_BASE_ID", value = var.bedrock_kb_id },
    ]
    secrets = [{
      name      = "WEBUI_SECRET_KEY"
      valueFrom = aws_ssm_parameter.webui_secret_key.arn
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.open_webui.name
        "awslogs-region"        = local.region
        "awslogs-stream-prefix" = "open-webui"
      }
    }
    healthCheck = {
      command     = ["CMD-SHELL", "curl -sf http://localhost:8080/health || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 60
    }
  }])
}

# ECS Fargate service
resource "aws_ecs_service" "open_webui" {
  name                 = "${var.project_name}-open-webui"
  cluster              = module.compute.ecs_cluster_arn
  task_definition      = aws_ecs_task_definition.open_webui.arn
  desired_count        = 1
  launch_type          = "FARGATE"
  force_new_deployment = true

  network_configuration {
    subnets          = local.private_subnet_ids
    security_groups  = [local.ecs_tasks_security_group_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.chat_frontend.arn
    container_name   = "open-webui"
    container_port   = 8080
  }
}

# Autoscaling - scale between 1 and 4 tasks based on CPU
resource "aws_appautoscaling_target" "open_webui" {
  max_capacity       = 4
  min_capacity       = 1
  resource_id        = "service/${module.compute.ecs_cluster_name}/${aws_ecs_service.open_webui.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "open_webui_cpu" {
  name               = "${var.project_name}-open-webui-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.open_webui.resource_id
  scalable_dimension = aws_appautoscaling_target.open_webui.scalable_dimension
  service_namespace  = aws_appautoscaling_target.open_webui.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 70.0
  }
}
