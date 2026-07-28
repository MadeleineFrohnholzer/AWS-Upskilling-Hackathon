variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "knowledge-base"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "cors_allowed_origins" {
  description = "Allowed origins for S3 CORS (browser PUT uploads). Use [\"*\"] for dev; lock to the upload page origin in prod."
  type        = list(string)
  default     = ["*"]
}
