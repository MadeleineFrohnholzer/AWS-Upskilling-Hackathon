# =============================================================================
# Team 1 Outputs — consumed by Team 2 via terraform_remote_state
# =============================================================================

output "landing_bucket_id" {
  description = "S3 landing bucket name (for presigned URL generation)"
  value       = module.storage.landing_bucket_id
}

output "landing_bucket_arn" {
  description = "S3 landing bucket ARN"
  value       = module.storage.landing_bucket_arn
}

output "processed_bucket_id" {
  description = "S3 processed documents bucket name"
  value       = module.storage.processed_bucket_id
}

output "presigned_url_lambda_name" {
  description = "Presigned URL generator Lambda function name"
  value       = module.presigned_url_lambda.lambda_function_name
}

output "bedrock_kb_id" {
  description = "Bedrock Knowledge Base ID (Team 2 needs this for agent tool-use)"
  value       = module.bedrock_kb.knowledge_base_id
}

output "bedrock_kb_arn" {
  description = "Bedrock Knowledge Base ARN"
  value       = module.bedrock_kb.knowledge_base_arn
}

output "upload_api_url" {
  description = "HTTP API Gateway endpoint — POST /upload to request a presigned S3 PUT URL"
  value       = module.presigned_url_lambda.api_endpoint
}
