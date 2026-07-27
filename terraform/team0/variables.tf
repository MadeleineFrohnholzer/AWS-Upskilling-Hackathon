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

variable "digest_sender_email" {
  description = "SES-verified sender address for the weekly digest"
  type        = string
  default     = "zoltan.szilagyi@accenture.com"
}

variable "digest_recipient_email" {
  description = "Email address to receive the weekly digest and CloudWatch alarm notifications"
  type        = string
  default     = "zoltan.szilagyi@accenture.com"
}
