variable "landing_bucket_id" {
  description = "Landing S3 bucket name"
  type        = string
}

variable "landing_bucket_arn" {
  description = "Landing S3 bucket ARN"
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs for Lambda VPC placement"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID for the Lambda function"
  type        = string
}

variable "presigned_url_expiry_minutes" {
  description = "How long presigned upload URLs remain valid"
  type        = number
  default     = 30
}

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
