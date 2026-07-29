# =============================================================================
# Compute Module — ECS Fargate, ALB, ECR
# =============================================================================

# -----------------------------------------------------------------------------
# ECR Repository
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

# -----------------------------------------------------------------------------
# ECS Task Execution Role (ECR pull + CloudWatch Logs)
# -----------------------------------------------------------------------------
resource "aws_iam_role" "ecs_task_execution" {
  name = "platform-ecs-task-execution"

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
  name = "platform-ecs-task-role"

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
      Resource = "arn:aws:bedrock:${local.region}:*:agent-alias/*/*"
    }]
  })
}

# -----------------------------------------------------------------------------
# ECS Task Definition
# -----------------------------------------------------------------------------
locals {
  region = data.aws_region.current.id

  # Open WebUI env vars that point it at the local proxy when the proxy is enabled
  webui_proxy_env = var.bedrock_agent_id != "" ? [
    { name = "OPENAI_API_BASE_URL", value = "http://localhost:${var.proxy_port}/v1" },
    { name = "OPENAI_API_KEY", value = "bedrock" },
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
        "awslogs-group"         = "/ecs/chat-application"
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
      { name = "BEDROCK_AGENT_ID", value = var.bedrock_agent_id },
      { name = "BEDROCK_AGENT_ALIAS_ID", value = var.bedrock_agent_alias_id },
      { name = "AWS_REGION", value = data.aws_region.current.id },
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/chat-application"
        "awslogs-region"        = data.aws_region.current.id
        "awslogs-stream-prefix" = "proxy"
      }
    }
  }

  container_definitions = var.proxy_image != "" ? [local.chat_container, local.proxy_container] : [local.chat_container]
}

resource "aws_ecs_task_definition" "chat_frontend" {
  family                   = "chat-application-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode(local.container_definitions)

  tags = {
    Name        = "chat-application-task"
    Environment = var.environment
  }
}

# -----------------------------------------------------------------------------
# CloudWatch Log Groups
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "chat_frontend" {
  name              = "/ecs/chat-application"
  retention_in_days = 14
}

# -----------------------------------------------------------------------------
# CloudWatch Metric Alarms
# -----------------------------------------------------------------------------

# ALB 5xx error rate > 1% over 5 minutes (metric math: 5xx / total * 100)
resource "aws_cloudwatch_metric_alarm" "alb_5xx_rate" {
  alarm_name          = "alb-5xx-rate-high"
  alarm_description   = "ALB target 5xx error rate exceeded ${var.alarm_5xx_threshold_pct}% over 5 minutes"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = var.alarm_5xx_threshold_pct
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.alarm_actions

  metric_query {
    id          = "e1"
    expression  = "m2/m1*100"
    label       = "5xx Error Rate (%)"
    return_data = true
  }

  metric_query {
    id = "m1"
    metric {
      namespace   = "AWS/ApplicationELB"
      metric_name = "RequestCount"
      period      = 300
      stat        = "Sum"
      dimensions  = { LoadBalancer = data.aws_lb.shared.arn_suffix }
    }
  }

  metric_query {
    id = "m2"
    metric {
      namespace   = "AWS/ApplicationELB"
      metric_name = "HTTPCode_Target_5XX_Count"
      period      = 300
      stat        = "Sum"
      dimensions  = { LoadBalancer = data.aws_lb.shared.arn_suffix }
    }
  }
}

# ALB target response time P95 > 20 seconds
resource "aws_cloudwatch_metric_alarm" "alb_latency_p95" {
  alarm_name          = "alb-latency-p95-high"
  alarm_description   = "ALB target response time P95 exceeded ${var.alarm_latency_p95_seconds}s over 5 minutes"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = var.alarm_latency_p95_seconds
  treat_missing_data  = "notBreaching"
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  extended_statistic  = "p95"
  alarm_actions       = var.alarm_actions

  dimensions = {
    LoadBalancer = data.aws_lb.shared.arn_suffix
  }
}

# ECS service CPU utilisation > 80% — dimensions filled once ECS service is deployed
resource "aws_cloudwatch_metric_alarm" "ecs_cpu" {
  alarm_name          = "ecs-cpu-high"
  alarm_description   = "ECS service CPU utilisation exceeded ${var.alarm_cpu_threshold_pct}%"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  threshold           = var.alarm_cpu_threshold_pct
  treat_missing_data  = "missing"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  alarm_actions       = var.alarm_actions

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = var.ecs_service_name
  }
}

# -----------------------------------------------------------------------------
# CloudWatch Dashboard
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "chat-application-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "ECS CPU Utilization (%)"
          view   = "timeSeries"
          region = data.aws_region.current.name
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", aws_ecs_cluster.main.name, { stat = "Average", period = 60, label = "CPU avg" }]
          ]
          yAxis = { left = { min = 0, max = 100 } }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "ECS Memory Utilization (%)"
          view   = "timeSeries"
          region = data.aws_region.current.name
          metrics = [
            ["AWS/ECS", "MemoryUtilization", "ClusterName", aws_ecs_cluster.main.name, { stat = "Average", period = 60, label = "Memory avg" }]
          ]
          yAxis = { left = { min = 0, max = 100 } }
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 8
        height = 6
        properties = {
          title  = "ALB Request Count"
          view   = "timeSeries"
          region = data.aws_region.current.name
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", data.aws_lb.shared.arn_suffix, { stat = "Sum", period = 60 }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 6
        width  = 8
        height = 6
        properties = {
          title  = "ALB 5xx Errors"
          view   = "timeSeries"
          region = data.aws_region.current.name
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", data.aws_lb.shared.arn_suffix, { stat = "Sum", period = 60, color = "#d62728" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 6
        width  = 8
        height = 6
        properties = {
          title  = "ALB Response Time P95 (s)"
          view   = "timeSeries"
          stat   = "p95"
          period = 60
          region = data.aws_region.current.name
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", data.aws_lb.shared.arn_suffix]
          ]
        }
      },
      {
        type   = "alarm"
        x      = 0
        y      = 12
        width  = 24
        height = 4
        properties = {
          title = "Active Alarms"
          alarms = [
            aws_cloudwatch_metric_alarm.alb_5xx_rate.arn,
            aws_cloudwatch_metric_alarm.alb_latency_p95.arn,
            aws_cloudwatch_metric_alarm.ecs_cpu.arn,
          ]
        }
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------
data "aws_region" "current" {}

data "aws_lb" "shared" {
  arn = var.alb_arn
}
