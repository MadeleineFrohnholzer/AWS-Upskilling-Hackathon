variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "knowledge-base"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "vpc_id" {
  description = "VPC ID for the ECS cluster"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for ECS tasks"
  type        = list(string)
}

variable "alb_arn" {
  description = "ARN of the shared internal ALB (from networking module). Used for CloudWatch alarms and dashboard."
  type        = string
}

variable "container_image" {
  description = "Docker image URI for the chat frontend"
  type        = string
  default     = "" # Set after pushing to ECR
}

variable "container_port" {
  description = "Port the container listens on"
  type        = number
  default     = 8080
}

variable "cpu" {
  description = "Fargate task CPU units"
  type        = number
  default     = 1024
}

variable "memory" {
  description = "Fargate task memory (MiB)"
  type        = number
  default     = 2048
}

variable "proxy_image" {
  description = "ECR image URI for the Bedrock proxy sidecar. Leave empty to run Open WebUI without the proxy."
  type        = string
  default     = ""
}

variable "proxy_port" {
  description = "Port the bedrock-proxy sidecar listens on"
  type        = number
  default     = 8000
}

variable "bedrock_agent_id" {
  description = "Bedrock Agent ID — passed to the proxy container as BEDROCK_AGENT_ID"
  type        = string
  default     = ""
}

variable "bedrock_agent_alias_id" {
  description = "Bedrock Agent Alias ID — passed to the proxy container as BEDROCK_AGENT_ALIAS_ID"
  type        = string
  default     = ""
}

variable "ecs_service_name" {
  description = "ECS service name for the CPU alarm dimension. Leave empty until the ECS service is created."
  type        = string
  default     = ""
}

variable "alarm_5xx_threshold_pct" {
  description = "ALB 5xx error rate (%) that triggers the alarm"
  type        = number
  default     = 1.0
}

variable "alarm_latency_p95_seconds" {
  description = "ALB P95 response time in seconds that triggers the alarm"
  type        = number
  default     = 20
}

variable "alarm_cpu_threshold_pct" {
  description = "ECS CPU utilisation (%) that triggers the alarm"
  type        = number
  default     = 80
}

variable "alarm_actions" {
  description = "List of SNS topic ARNs to notify when an alarm changes state"
  type        = list(string)
  default     = []
}
