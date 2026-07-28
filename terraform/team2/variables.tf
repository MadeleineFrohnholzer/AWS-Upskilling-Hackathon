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

variable "bedrock_agent_id" {
  description = "Bedrock Agent ID (from Issue37 output)"
  type        = string
  default     = ""
}

variable "bedrock_agent_alias_id" {
  description = "Bedrock Agent alias ID (from Issue37 output)"
  type        = string
  default     = ""
}

variable "bedrock_kb_id" {
  description = "Bedrock Knowledge Base ID from Team 1"
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------------
# Cognito / Entra ID SSO variables
# -----------------------------------------------------------------------------
variable "entra_tenant_id" {
  description = "Azure Entra ID (AAD) tenant ID"
  type        = string
  default     = ""
}

variable "entra_client_id" {
  description = "Entra ID app registration client ID"
  type        = string
  default     = ""
}

variable "entra_client_secret" {
  description = "Entra ID app registration client secret"
  type        = string
  sensitive   = true
  default     = ""
}

variable "cognito_callback_urls" {
  description = "Allowed callback URLs for the Cognito app client (ALB HTTPS endpoint)"
  type        = list(string)
  default     = []
}

variable "cognito_logout_urls" {
  description = "Allowed logout URLs for the Cognito app client"
  type        = list(string)
  default     = []
}