variable "project_name" {
  description = "Project name prefix for resource naming"
  type        = string
  default     = "knowledge-base"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}
