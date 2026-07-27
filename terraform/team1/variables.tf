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

variable "entra_tenant_id" {
  description = "Microsoft Entra (Azure AD) tenant ID for SSO federation"
  type        = string
  default     = "REPLACE_WITH_ENTRA_TENANT_ID"
}

variable "entra_client_id" {
  description = "Microsoft Entra App registration client ID"
  type        = string
  default     = "REPLACE_WITH_ENTRA_CLIENT_ID"
}

variable "entra_client_secret" {
  description = "Microsoft Entra App registration client secret"
  type        = string
  sensitive   = true
  default     = "REPLACE_WITH_ENTRA_CLIENT_SECRET"
}

variable "open_webui_image" {
  description = "Docker image for Open WebUI — push to ECR first, then set this to ECR URL:tag"
  type        = string
  default     = ""  # empty = use ECR repo URL:latest (see locals in main.tf)
}
