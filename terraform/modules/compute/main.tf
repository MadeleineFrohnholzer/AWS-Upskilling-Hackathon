# =============================================================================
# Compute Module — ECR Repository, ECS Cluster, IAM Task Execution Role
# =============================================================================
# Provides the shared compute primitives used by the root module to run the
# chat-ui container. The ECS task definition and service live in the root
# module so they have direct access to all module outputs (networking, storage,
# Bedrock agent, etc.) without needing to thread every value through here.
# =============================================================================

# -----------------------------------------------------------------------------
# ECR Repository — stores the chat-frontend Docker image
# -----------------------------------------------------------------------------
resource "aws_ecr_repository" "chat_frontend" {
  name                 = "chat-application-image-repo"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "chat-application-image-repo"
    Environment = var.environment
  }
}

resource "aws_ecr_lifecycle_policy" "chat_frontend" {
  repository = aws_ecr_repository.chat_frontend.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 tagged images, expire untagged after 1 day"
      selection = {
        tagStatus   = "untagged"
        countType   = "sinceImagePushed"
        countUnit   = "days"
        countNumber = 1
      }
      action = { type = "expire" }
    }]
  })
}

# -----------------------------------------------------------------------------
# ECS Cluster
# -----------------------------------------------------------------------------
resource "aws_ecs_cluster" "main" {
  name = "chat-application-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name        = "chat-application-cluster"
    Environment = var.environment
  }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name       = aws_ecs_cluster.main.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
  }
}

# -----------------------------------------------------------------------------
# ECS Task Execution Role
# Grants ECS permission to pull images from ECR and write to CloudWatch Logs.
# Additional policy (SSM, Secrets Manager) is attached by the root module.
# -----------------------------------------------------------------------------
resource "aws_iam_role" "ecs_task_execution" {
  name = "platform-ecs-task-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })

  tags = {
    Name        = "platform-${var.project_name}-ecs-task-execution"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# -----------------------------------------------------------------------------
# CloudWatch Log Group
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "chat_frontend" {
  name              = "/ecs/chat-ui"
  retention_in_days = 14
}

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------
data "aws_region" "current" {}
