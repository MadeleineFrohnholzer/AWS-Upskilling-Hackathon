variable "processed_bucket_id" {
  description = "Processed S3 bucket name"
  type        = string
}

variable "processed_bucket_arn" {
  description = "Processed S3 bucket ARN"
  type        = string
}

variable "audit_table_name" {
  description = "Name of the document audit trail DynamoDB table"
  type        = string
}

variable "audit_table_arn" {
  description = "ARN of the document audit trail DynamoDB table"
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
