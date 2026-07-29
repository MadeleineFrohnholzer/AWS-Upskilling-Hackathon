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

# -----------------------------------------------------------------------------
# Networking
# -----------------------------------------------------------------------------

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "availability_zones" {
  description = "AZs for subnets"
  type        = list(string)
  default     = ["eu-central-1a", "eu-central-1b"]
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for outbound internet from private subnets"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# Compute / App
# -----------------------------------------------------------------------------

variable "open_webui_image" {
  description = "Docker image URI for Open WebUI (pushed to ECR before applying)"
  type        = string
  default     = ""
}

variable "proxy_image" {
  description = "ECR image URI for the bedrock-proxy sidecar. Set after pushing the image."
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------------
# Cognito / Entra ID SSO
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
