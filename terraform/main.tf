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
    key            = "terraform.tfstate"
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
      ManagedBy   = "terraform"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  vpc_id                      = module.networking.vpc_id
  private_subnet_ids          = module.networking.private_subnet_ids
  lambda_security_group_id    = module.networking.lambda_security_group_id
  alb_arn                     = module.networking.alb_arn
  alb_listener_arn            = module.networking.alb_listener_arn
  ecs_tasks_security_group_id = module.networking.ecs_tasks_security_group_id
  account_id                  = data.aws_caller_identity.current.account_id
  region                      = data.aws_region.current.region
  container_image             = var.chat_ui_image != "" ? var.chat_ui_image : "${module.compute.ecr_repository_url}:latest"
}

# =============================================================================
# Networking (formerly shared)
# =============================================================================

module "networking" {
  source = "./modules/networking"

  project_name         = var.project_name
  region               = var.region
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
  enable_nat_gateway   = var.enable_nat_gateway
  vpn_egress_cidrs     = var.vpn_egress_cidrs
}

# =============================================================================
# Storage (formerly team1)
# =============================================================================

module "storage" {
  source = "./modules/storage"

  project_name = var.project_name
  environment  = var.environment
}

module "presigned_url_lambda" {
  source = "./modules/presigned-url-lambda"

  landing_bucket_id            = module.storage.landing_bucket_id
  landing_bucket_arn           = module.storage.landing_bucket_arn
  subnet_ids                   = local.private_subnet_ids
  security_group_id            = local.lambda_security_group_id
  presigned_url_expiry_minutes = 30

  project_name = var.project_name
  environment  = var.environment
}

module "ingest_lambda" {
  source = "./modules/ingest-lambda"

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

module "bedrock_kb" {
  source = "./modules/bedrock-kb"

  processed_bucket_id  = module.storage.processed_bucket_id
  processed_bucket_arn = module.storage.processed_bucket_arn
  region               = var.region

  project_name = var.project_name
  environment  = var.environment
}

module "audit_lambda" {
  source = "./modules/audit-lambda"

  processed_bucket_id  = module.storage.processed_bucket_id
  processed_bucket_arn = module.storage.processed_bucket_arn
  audit_table_name     = module.storage.upload_audit_table_name
  audit_table_arn      = module.storage.upload_audit_table_arn
  subnet_ids           = local.private_subnet_ids
  security_group_id    = local.lambda_security_group_id

  project_name = var.project_name
  environment  = var.environment
}

# =============================================================================
# Bedrock Agent (formerly team2)
# =============================================================================

module "bedrock_agent" {
  source = "./modules/bedrock-agent"

  project_name       = var.project_name
  environment        = var.environment
  knowledge_base_id  = module.bedrock_kb.knowledge_base_id
  knowledge_base_arn = module.bedrock_kb.knowledge_base_arn
}

module "bedrock_proxy" {
  source = "./modules/bedrock-proxy"

  project_name = var.project_name
  environment  = var.environment
}

module "compute" {
  source = "./modules/compute"

  project_name = var.project_name
  environment  = var.environment
}

# =============================================================================
# Cognito User Pool + Entra ID SSO Federation
# =============================================================================

resource "aws_cognito_user_pool" "main" {
  name = "user-authentication-pool"

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

resource "aws_cognito_user_pool_domain" "main" {
  domain       = "chat-application-auth"
  user_pool_id = aws_cognito_user_pool.main.id
}

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
  name         = "chat-app-auth-client"
  user_pool_id = aws_cognito_user_pool.main.id

  generate_secret = true

  allowed_oauth_flows_user_pool_client = length(compact(var.cognito_callback_urls)) > 0
  allowed_oauth_flows                  = length(compact(var.cognito_callback_urls)) > 0 ? ["code"] : []
  allowed_oauth_scopes                 = length(compact(var.cognito_callback_urls)) > 0 ? ["openid", "email", "profile"] : []
  supported_identity_providers         = var.entra_tenant_id != "" ? ["EntraID"] : ["COGNITO"]

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

# =============================================================================
# IAM — ECS Task Role
# =============================================================================

resource "aws_iam_role" "ecs_task" {
  name = "platform-chat-application-task"

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
  name = "chat-ui-permissions"
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
          "arn:aws:bedrock:${local.region}:${local.account_id}:agent/${module.bedrock_agent.agent_id}",
          "arn:aws:bedrock:${local.region}:${local.account_id}:agent-alias/${module.bedrock_agent.agent_id}/*",
          "arn:aws:bedrock:${local.region}:${local.account_id}:knowledge-base/${module.bedrock_kb.knowledge_base_id}",
        ]
      },
      {
        Sid    = "DynamoDBChatHistory"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:Query",
        ]
        Resource = [
          module.storage.chat_history_table_arn,
          "${module.storage.chat_history_table_arn}/index/*",
        ]
      },
      {
        Sid      = "LambdaPresignedUrl"
        Effect   = "Allow"
        Action   = ["lambda:InvokeFunction"]
        Resource = [module.presigned_url_lambda.lambda_function_arn]
      },
    ]
  })
}

# =============================================================================
# ALB HTTPS Listener (required for Cognito authenticate-cognito action)
# =============================================================================

resource "aws_lb_listener" "https" {
  count             = var.alb_certificate_arn != "" ? 1 : 0
  load_balancer_arn = local.alb_arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.alb_certificate_arn

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Not found"
      status_code  = "404"
    }
  }
}

# =============================================================================
# ALB Target Group + Listener Rules
# =============================================================================

resource "aws_lb_target_group" "chat_frontend" {
  name        = "chat-application-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = local.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = "/api/health"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }
}

resource "aws_lb_listener_rule" "chat_frontend" {
  count        = length(compact(var.cognito_callback_urls)) > 0 && var.alb_certificate_arn != "" ? 1 : 0
  listener_arn = aws_lb_listener.https[0].arn
  priority     = 100

  action {
    type  = "authenticate-cognito"
    order = 1
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
    order            = 2
    target_group_arn = aws_lb_target_group.chat_frontend.arn
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }
}

resource "aws_lb_listener_rule" "chat_frontend_noauth" {
  count        = length(compact(var.cognito_callback_urls)) > 0 ? 0 : 1
  listener_arn = local.alb_listener_arn
  priority     = 100

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
# ECS Task Definition + Service + Autoscaling
# =============================================================================

resource "aws_ecs_task_definition" "chat_ui" {
  family                   = "chat-ui-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = module.compute.ecs_task_execution_role_arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name         = "chat-frontend"
    image        = local.container_image
    portMappings = [{ containerPort = 3000, protocol = "tcp" }]
    environment = [
      { name = "AWS_REGION", value = local.region },
      { name = "BEDROCK_AGENT_ID", value = module.bedrock_agent.agent_id },
      { name = "BEDROCK_AGENT_ALIAS_ID", value = module.bedrock_agent.agent_alias_id },
      { name = "KNOWLEDGE_BASE_ID", value = module.bedrock_kb.knowledge_base_id },
      { name = "DYNAMODB_TABLE_NAME", value = module.storage.chat_history_table_name },
      { name = "UPLOAD_LAMBDA_NAME", value = module.presigned_url_lambda.lambda_function_name },
      { name = "NEXT_PUBLIC_APP_NAME", value = "Knowledge Assistant" },
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = module.compute.chat_frontend_log_group_name
        "awslogs-region"        = local.region
        "awslogs-stream-prefix" = "chat-ui"
      }
    }
    healthCheck = {
      command     = ["CMD-SHELL", "curl -sf http://localhost:3000/api/health || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 60
    }
  }])
}

resource "aws_ecs_service" "chat_ui" {
  name                 = "chat-ui-service"
  cluster              = module.compute.ecs_cluster_arn
  task_definition      = aws_ecs_task_definition.chat_ui.arn
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
    container_name   = "chat-frontend"
    container_port   = 3000
  }
}

resource "aws_appautoscaling_target" "chat_ui" {
  max_capacity       = 4
  min_capacity       = 1
  resource_id        = "service/${module.compute.ecs_cluster_name}/${aws_ecs_service.chat_ui.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "chat_ui_cpu" {
  name               = "chat-ui-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.chat_ui.resource_id
  scalable_dimension = aws_appautoscaling_target.chat_ui.scalable_dimension
  service_namespace  = aws_appautoscaling_target.chat_ui.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 70.0
  }
}

# -----------------------------------------------------------------------------
# CloudWatch Alarms — reference the shared ALB (not the compute module's dead ALB)
# -----------------------------------------------------------------------------

# Data source to resolve the ARN suffix of the shared ALB for CloudWatch dimensions
data "aws_lb" "shared" {
  arn = local.alb_arn
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx_rate" {
  alarm_name          = "${var.project_name}-alb-5xx-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  threshold           = 1.0
  alarm_description   = "ALB 5xx error rate exceeded 1% for 2 consecutive minutes"
  treat_missing_data  = "notBreaching"

  metric_query {
    id          = "error_rate"
    expression  = "100 * errors / MAX([errors, requests])"
    label       = "5xx rate (%)"
    return_data = true
  }
  metric_query {
    id = "errors"
    metric {
      namespace   = "AWS/ApplicationELB"
      metric_name = "HTTPCode_Target_5XX_Count"
      period      = 60
      stat        = "Sum"
      dimensions  = { LoadBalancer = data.aws_lb.shared.arn_suffix }
    }
  }
  metric_query {
    id = "requests"
    metric {
      namespace   = "AWS/ApplicationELB"
      metric_name = "RequestCount"
      period      = 60
      stat        = "Sum"
      dimensions  = { LoadBalancer = data.aws_lb.shared.arn_suffix }
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "alb_latency_p95" {
  alarm_name          = "${var.project_name}-alb-latency-p95"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  threshold           = 20
  alarm_description   = "ALB P95 response time exceeded 20s for 2 consecutive minutes"
  treat_missing_data  = "notBreaching"

  namespace          = "AWS/ApplicationELB"
  metric_name        = "TargetResponseTime"
  period             = 60
  extended_statistic = "p95"
  dimensions         = { LoadBalancer = data.aws_lb.shared.arn_suffix }
}

resource "aws_cloudwatch_metric_alarm" "ecs_cpu" {
  alarm_name          = "${var.project_name}-ecs-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  threshold           = 80
  alarm_description   = "ECS service CPU utilisation exceeded 80% — autoscaling may be lagging"
  treat_missing_data  = "notBreaching"

  namespace   = "AWS/ECS"
  metric_name = "CPUUtilization"
  period      = 60
  statistic   = "Average"
  dimensions = {
    ClusterName = module.compute.ecs_cluster_name
    ServiceName = aws_ecs_service.chat_ui.name
  }
}

# -----------------------------------------------------------------------------
# CloudWatch Dashboard
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-chat-frontend"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "ALB Request Count"
          region = local.region
          metrics = [[
            "AWS/ApplicationELB",
            "RequestCount",
            "LoadBalancer", data.aws_lb.shared.arn_suffix,
            { stat = "Sum", period = 60 }
          ]]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "ALB 5xx Count"
          region = local.region
          metrics = [[
            "AWS/ApplicationELB",
            "HTTPCode_Target_5XX_Count",
            "LoadBalancer", data.aws_lb.shared.arn_suffix,
            { stat = "Sum", period = 60, color = "#d62728" }
          ]]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "ALB P95 Latency (s)"
          region = local.region
          metrics = [[
            "AWS/ApplicationELB",
            "TargetResponseTime",
            "LoadBalancer", data.aws_lb.shared.arn_suffix,
            { stat = "p95", period = 60, color = "#ff7f0e" }
          ]]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "ECS CPU Utilisation (%)"
          region = local.region
          metrics = [[
            "AWS/ECS",
            "CPUUtilization",
            "ClusterName", module.compute.ecs_cluster_name,
            "ServiceName", aws_ecs_service.chat_ui.name,
            { stat = "Average", period = 60, color = "#9467bd" }
          ]]
        }
      }
    ]
  })
}
