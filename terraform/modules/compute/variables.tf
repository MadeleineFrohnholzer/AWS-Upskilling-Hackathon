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
