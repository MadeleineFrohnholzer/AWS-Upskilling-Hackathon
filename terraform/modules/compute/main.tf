# =============================================================================
# Compute Module — ECS Fargate, ALB, ECR
# =============================================================================

# -----------------------------------------------------------------------------
# ECR Repository
# -----------------------------------------------------------------------------
resource "aws_ecr_repository" "chat_frontend" {
  name                 = "${var.project_name}-chat-frontend"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "${var.project_name}-chat-frontend"
    Environment = var.environment
  }
}

# -----------------------------------------------------------------------------
# ECS Cluster
# -----------------------------------------------------------------------------
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name        = "${var.project_name}-cluster"
    Environment = var.environment
  }
}

# -----------------------------------------------------------------------------
# ECS Task Execution Role (ECR pull + CloudWatch Logs)
# -----------------------------------------------------------------------------
resource "aws_iam_role" "ecs_task_execution" {
  name = "platform-${var.project_name}-ecs-task-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECS Task Role — grants the running containers permissions to call AWS APIs
resource "aws_iam_role" "ecs_task_role" {
  name = "platform-${var.project_name}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "bedrock_agent_invoke" {
  name = "bedrock-agent-invoke"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["bedrock:InvokeAgent"]
      Resource = "arn:aws:bedrock:${data.aws_region.current.id}:*:agent-alias/*/*"
    }]
  })
}

# -----------------------------------------------------------------------------
# ECS Task Definition
# -----------------------------------------------------------------------------
locals {
  # Open WebUI env vars that point it at the local proxy when the proxy is enabled
  webui_proxy_env = var.bedrock_agent_id != "" ? [
    { name = "OPENAI_API_BASE_URL", value = "http://localhost:${var.proxy_port}/v1" },
    { name = "OPENAI_API_KEY",      value = "bedrock" },
  ] : []

  chat_container = {
    name  = "chat-frontend"
    image = var.container_image != "" ? var.container_image : "${aws_ecr_repository.chat_frontend.repository_url}:latest"
    portMappings = [{
      containerPort = var.container_port
      protocol      = "tcp"
    }]
    environment = local.webui_proxy_env
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/${var.project_name}-chat-frontend"
        "awslogs-region"        = data.aws_region.current.id
        "awslogs-stream-prefix" = "chat"
      }
    }
  }

  proxy_container = {
    name  = "bedrock-proxy"
    image = var.proxy_image
    portMappings = [{
      containerPort = var.proxy_port
      protocol      = "tcp"
    }]
    environment = [
      { name = "BEDROCK_AGENT_ID",       value = var.bedrock_agent_id },
      { name = "BEDROCK_AGENT_ALIAS_ID", value = var.bedrock_agent_alias_id },
      { name = "AWS_REGION",             value = data.aws_region.current.id },
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/${var.project_name}-chat-frontend"
        "awslogs-region"        = data.aws_region.current.id
        "awslogs-stream-prefix" = "proxy"
      }
    }
  }

  container_definitions = var.proxy_image != "" ? [local.chat_container, local.proxy_container] : [local.chat_container]
}

resource "aws_ecs_task_definition" "chat_frontend" {
  family                   = "${var.project_name}-chat-frontend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode(local.container_definitions)

  tags = {
    Name        = "${var.project_name}-chat-frontend"
    Environment = var.environment
  }
}

# -----------------------------------------------------------------------------
# CloudWatch Log Group
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "chat_frontend" {
  name              = "/ecs/${var.project_name}-chat-frontend"
  retention_in_days = 14
}

# -----------------------------------------------------------------------------
# Security Group for ECS Tasks
# -----------------------------------------------------------------------------
resource "aws_security_group" "ecs_tasks" {
  name_prefix = "${var.project_name}-ecs-tasks-"
  vpc_id      = var.vpc_id
  description = "Security group for ECS Fargate tasks"

  ingress {
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "Allow traffic from ALB"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name = "${var.project_name}-ecs-tasks-sg"
  }
}

# -----------------------------------------------------------------------------
# Internal ALB
# -----------------------------------------------------------------------------
resource "aws_security_group" "alb" {
  name_prefix = "${var.project_name}-alb-"
  vpc_id      = var.vpc_id
  description = "Security group for internal ALB"

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"] # Corporate VPN CIDR — adjust as needed
    description = "HTTPS from VPN"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name = "${var.project_name}-alb-sg"
  }
}

resource "aws_lb" "internal" {
  name               = "${var.project_name}-internal-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.private_subnet_ids

  tags = {
    Name        = "${var.project_name}-internal-alb"
    Environment = var.environment
  }
}

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------
data "aws_region" "current" {}
