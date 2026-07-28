variable "project_name" {
  description = "Project name"
  type        = string
  default     = "knowledge-base"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "open_webui_image" {
  description = "Docker image URI for Open WebUI (pushed to ECR before applying)"
  type        = string
  default     = ""
}

variable "knowledge_base_id" {
  description = "Bedrock Knowledge Base ID from Team 1. Leave empty until the KB is deployed."
  type        = string
  default     = ""
}

variable "knowledge_base_arn" {
  description = "Bedrock Knowledge Base ARN from Team 1. Leave empty until the KB is deployed."
  type        = string
  default     = ""
}

variable "proxy_image" {
  description = "ECR image URI for the bedrock-proxy sidecar. Set after pushing the image."
  type        = string
  default     = ""
}
