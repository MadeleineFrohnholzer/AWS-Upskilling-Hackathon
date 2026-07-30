variable "project_name" {
  description = "Project name prefix for resource naming"
  type        = string
  default     = "knowledge-base"
}

variable "environment" {
  description = "Environment name (also used as the agent alias name)"
  type        = string
  default     = "dev"
}

variable "knowledge_base_id" {
  description = "Bedrock Knowledge Base ID from Team 1. Leave empty until the KB is deployed."
  type        = string
  default     = ""
}

variable "knowledge_base_arn" {
  description = "Bedrock Knowledge Base ARN from Team 1. Leave empty until the KB is deployed."
  type        = string
  default     = ""
}

variable "foundation_model_id" {
  description = "Bedrock foundation model ID for the agent. Must be available in the deployment region."
  type        = string
  default     = "anthropic.claude-sonnet-4-5-20250929-v1:0"
}

variable "agent_instruction" {
  description = "System instruction that controls how the agent answers questions"
  type        = string
  default     = <<-EOT
    You are a knowledgeable assistant with access to an internal document knowledge base.
    When answering questions, always retrieve relevant documents first and base your answers
    strictly on the retrieved content. For every factual claim you make, include an inline
    citation in the format [Source: <filename>, Page <n>]. If the retrieved documents do not
    contain enough information to answer the question, say so clearly — never guess or fabricate
    sources. Do not answer questions that are unrelated to the documents in the knowledge base.
  EOT
}
