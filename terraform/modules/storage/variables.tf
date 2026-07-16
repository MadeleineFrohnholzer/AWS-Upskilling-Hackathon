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
