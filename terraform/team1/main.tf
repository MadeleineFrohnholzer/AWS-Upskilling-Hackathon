# =============================================================================
# Team 1 — Access / Knowledge App (Milestone 1)
# =============================================================================
# Owns: Cognito, ECS Fargate (Open WebUI), ECR, Bedrock Agent, ALB listener rules

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
      Team        = "team1-app"
      ManagedBy   = "terraform"
    }
  }
}

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "terraform_remote_state" "shared" {
  backend = "s3"
  config = {
    bucket = "hackathon-tf-state-064453091991"
    key    = "shared/terraform.tfstate"
    region = "eu-central-1"
  }
}

data "terraform_remote_state" "team0" {
  backend = "s3"
  config = {
    bucket = "hackathon-tf-state-064453091991"
    key    = "team0/terraform.tfstate"
    region = "eu-central-1"
  }
}

locals {
  vpc_id                      = data.terraform_remote_state.shared.outputs.vpc_id
  private_subnet_ids          = data.terraform_remote_state.shared.outputs.private_subnet_ids
  alb_arn                     = data.terraform_remote_state.shared.outputs.alb_arn
  alb_listener_arn            = data.terraform_remote_state.shared.outputs.alb_listener_arn
  alb_dns_name                = data.terraform_remote_state.shared.outputs.alb_dns_name
  ecs_tasks_security_group_id = data.terraform_remote_state.shared.outputs.ecs_tasks_security_group_id
  bedrock_kb_id               = data.terraform_remote_state.team0.outputs.bedrock_kb_id
  account_id                  = data.aws_caller_identity.current.account_id
  region                      = data.aws_region.current.name
  container_image             = var.open_webui_image != "" ? var.open_webui_image : "${module.compute.ecr_repository_url}:latest"
}

# =============================================================================
# Compute Module — ECS Cluster, ECR, task-execution IAM role
# =============================================================================
module "compute" {
  source = "../modules/compute"

  project_name       = var.project_name
  environment        = var.environment
  vpc_id             = local.vpc_id
  private_subnet_ids = local.private_subnet_ids
}

# =============================================================================
# Cognito User Pool — SSO authentication front door
# =============================================================================
resource "aws_cognito_user_pool" "main" {
  name = "${var.project_name}-users"

  admin_create_user_config {
    allow_admin_create_user_only = true  # users come exclusively via Entra ID SSO
  }

  password_policy {
    minimum_length                   = 12
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = true
    require_uppercase                = true
    temporary_password_validity_days = 1
  }

  auto_verified_attributes = ["email"]
  username_attributes      = ["email"]

  schema {
    attribute_data_type      = "String"
    name                     = "email"
    required                 = true
    mutable                  = true
    developer_only_attribute = false
    string_attribute_constraints {
      min_length = 3
      max_length = 254
    }
  }

  tags = { Name = "${var.project_name}-users" }
}

# Cognito hosted-UI domain — used by ALB authenticator redirect
resource "aws_cognito_user_pool_domain" "main" {
  domain       = "${var.project_name}-${local.account_id}"
  user_pool_id = aws_cognito_user_pool.main.id
}

# Microsoft Entra ID OIDC identity provider
resource "aws_cognito_identity_provider" "entra" {
  user_pool_id  = aws_cognito_user_pool.main.id
  provider_name = "EntraID"
  provider_type = "OIDC"

  provider_details = {
    client_id                 = var.entra_client_id
    client_secret             = var.entra_client_secret
    attributes_request_method = "GET"
    oidc_issuer               = "https://login.microsoftonline.com/${var.entra_tenant_id}/v2.0"
    authorize_scopes          = "openid email profile"
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

# Cognito App Client — used by the ALB listener rule authenticator
resource "aws_cognito_user_pool_client" "open_webui" {
  name         = "open-webui-alb"
  user_pool_id = aws_cognito_user_pool.main.id

  generate_secret = true

  allowed_oauth_flows                  = ["code"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                 = ["email", "openid", "profile"]

  callback_urls = ["https://${local.alb_dns_name}/oauth2/idpresponse"]
  logout_urls   = ["https://${local.alb_dns_name}"]

  supported_identity_providers = ["EntraID"]

  depends_on = [aws_cognito_identity_provider.entra]
}

# =============================================================================
# ALB Target Group + Listener Rule (attach to SHARED ALB)
# =============================================================================
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

  tags = { Name = "${var.project_name}-chat-tg" }
}

# ALB listener rule: authenticate via Cognito, then forward to ECS
resource "aws_lb_listener_rule" "chat_frontend" {
  listener_arn = local.alb_listener_arn
  priority     = 100

  action {
    type = "authenticate-cognito"
    authenticate_cognito {
      user_pool_arn              = aws_cognito_user_pool.main.arn
      user_pool_client_id        = aws_cognito_user_pool_client.open_webui.id
      user_pool_domain           = aws_cognito_user_pool_domain.main.domain
      on_unauthenticated_request = "authenticate"
      session_cookie_name        = "AWSELBAuthSessionCookie"
      session_timeout            = 28800  # 8 hours
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

# =============================================================================
# ECS Task Definition — Open WebUI with Bedrock Agent env vars
# =============================================================================

# SSM parameter for Open WebUI session-signing key (set value after first deploy)
resource "aws_ssm_parameter" "webui_secret_key" {
  name  = "/${var.project_name}/open-webui/secret-key"
  type  = "SecureString"
  value = "REPLACE_ME_CHANGE_AFTER_FIRST_DEPLOY_MIN_32_CHARS"

  lifecycle {
    ignore_changes = [value]  # value is managed out-of-band after initial creation
  }
}

resource "aws_cloudwatch_log_group" "open_webui" {
  name              = "/ecs/${var.project_name}-open-webui"
  retention_in_days = 14
}

# ECS task role — runtime AWS API calls from within the container
resource "aws_iam_role" "ecs_task" {
  name = "${var.project_name}-open-webui-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "ecs_task" {
  name = "open-webui-bedrock-access"
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
          "arn:aws:bedrock:${local.region}:${local.account_id}:agent/${aws_bedrockagent_agent.main.agent_id}",
          "arn:aws:bedrock:${local.region}:${local.account_id}:agent-alias/${aws_bedrockagent_agent.main.agent_id}/*",
          "arn:aws:bedrock:${local.region}:${local.account_id}:knowledge-base/${local.bedrock_kb_id}",
        ]
      },
      {
        Sid      = "SSMReadSecret"
        Effect   = "Allow"
        Action   = ["ssm:GetParameter"]
        Resource = aws_ssm_parameter.webui_secret_key.arn
      }
    ]
  })
}

# Grant the execution role (which pulls secrets at container start) access to SSM
resource "aws_iam_role_policy" "ecs_exec_ssm" {
  name = "ssm-read-webui-secret"
  role = module.compute.ecs_task_execution_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ssm:GetParameter", "ssm:GetParameters"]
      Resource = aws_ssm_parameter.webui_secret_key.arn
    }]
  })
}

resource "aws_ecs_task_definition" "open_webui" {
  family                   = "${var.project_name}-open-webui"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = module.compute.ecs_task_execution_role_arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name  = "open-webui"
    image = local.container_image
    portMappings = [{
      containerPort = 8080
      protocol      = "tcp"
    }]
    environment = [
      { name = "WEBUI_AUTH", value = "true" },
      { name = "ENABLE_SIGNUP", value = "false" },
      { name = "DEFAULT_USER_ROLE", value = "user" },
      { name = "AWS_REGION", value = local.region },
      { name = "BEDROCK_AGENT_ID", value = aws_bedrockagent_agent.main.agent_id },
      { name = "BEDROCK_AGENT_ALIAS_ID", value = aws_bedrockagent_agent_alias.live.agent_alias_id },
      { name = "KNOWLEDGE_BASE_ID", value = local.bedrock_kb_id },
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

  tags = { Name = "${var.project_name}-open-webui" }
}

resource "aws_ecs_service" "open_webui" {
  name            = "${var.project_name}-open-webui"
  cluster         = module.compute.ecs_cluster_arn
  task_definition = aws_ecs_task_definition.open_webui.arn
  desired_count   = 1
  launch_type     = "FARGATE"

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

  depends_on = [aws_lb_listener_rule.chat_frontend]

  tags = { Name = "${var.project_name}-open-webui" }
}

# =============================================================================
# Bedrock Agent — tool-use retrieval with grounded answers + inline citations
# =============================================================================
resource "aws_iam_role" "bedrock_agent" {
  name = "${var.project_name}-bedrock-agent"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "bedrock.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = {
        StringEquals = { "aws:SourceAccount" = local.account_id }
        ArnLike = {
          "aws:SourceArn" = "arn:aws:bedrock:${local.region}:${local.account_id}:agent/*"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "bedrock_agent" {
  name = "bedrock-agent-kb-access"
  role = aws_iam_role.bedrock_agent.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "InvokeModel"
        Effect = "Allow"
        Action = ["bedrock:InvokeModel"]
        Resource = [
          "arn:aws:bedrock:${local.region}::foundation-model/anthropic.claude-3-5-sonnet-20241022-v2:0",
          "arn:aws:bedrock:${local.region}::foundation-model/anthropic.claude-3-sonnet-20240229-v1:0",
        ]
      },
      {
        Sid    = "KnowledgeBaseRetrieve"
        Effect = "Allow"
        Action = [
          "bedrock:Retrieve",
          "bedrock:RetrieveAndGenerate",
        ]
        Resource = "arn:aws:bedrock:${local.region}:${local.account_id}:knowledge-base/${local.bedrock_kb_id}"
      }
    ]
  })
}

resource "aws_bedrockagent_agent" "main" {
  agent_name              = "${var.project_name}-agent"
  description             = "Knowledge retrieval agent — searches Team 0 KB and returns cited answers"
  agent_resource_role_arn = aws_iam_role.bedrock_agent.arn
  foundation_model        = "anthropic.claude-3-5-sonnet-20241022-v2:0"

  idle_session_ttl_in_seconds = 600

  instruction = <<-EOT
    You are a helpful knowledge assistant for Accenture consultants.
    When a user asks a question, search the knowledge base for relevant documents.
    Always base your answers strictly on the retrieved content — do not make up information.
    For every factual claim, cite the source document with the format: [Source: <filename>, Page <N>].
    Place citations inline, immediately after the sentence they support.
    If no relevant documents are found, say so clearly rather than guessing.
    Keep answers concise but complete. Use bullet points for lists of findings.
  EOT

  prepare_agent = true
}

resource "aws_bedrockagent_agent_knowledge_base_association" "main" {
  agent_id             = aws_bedrockagent_agent.main.agent_id
  description          = "Team 0 Knowledge Base — document corpus for retrieval"
  knowledge_base_id    = local.bedrock_kb_id
  knowledge_base_state = "ENABLED"
}

resource "aws_bedrockagent_agent_alias" "live" {
  agent_id         = aws_bedrockagent_agent.main.agent_id
  agent_alias_name = "live"
  description      = "Stable alias used by Open WebUI — points to DRAFT during hackathon"

  depends_on = [aws_bedrockagent_agent_knowledge_base_association.main]
}
