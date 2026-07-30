variable "audit_table_name" {
  description = "Name of the document audit trail DynamoDB table"
  type        = string
}

variable "audit_table_arn" {
  description = "ARN of the document audit trail DynamoDB table"
  type        = string
}

variable "sender_email" {
  description = "Verified SES email address used as sender and recipient"
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
