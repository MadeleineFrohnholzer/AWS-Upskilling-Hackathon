variable "landing_bucket_id" {
  description = "Landing S3 bucket name"
  type        = string
}

variable "landing_bucket_arn" {
  description = "Landing S3 bucket ARN"
  type        = string
}

variable "processed_bucket_id" {
  description = "Processed S3 bucket name"
  type        = string
}

variable "processed_bucket_arn" {
  description = "Processed S3 bucket ARN"
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

variable "kb_id" {
  description = "Bedrock Knowledge Base ID"
  type        = string
}

variable "kb_data_source_id" {
  description = "Bedrock Knowledge Base data source ID"
  type        = string
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
