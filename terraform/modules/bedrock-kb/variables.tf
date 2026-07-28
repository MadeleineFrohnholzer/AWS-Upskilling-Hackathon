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

variable "region" {
  description = "AWS region"
  type        = string
}

variable "processed_bucket_id" {
  description = "Processed S3 bucket name (documents to index)"
  type        = string
}

variable "processed_bucket_arn" {
  description = "Processed S3 bucket ARN"
  type        = string
}

