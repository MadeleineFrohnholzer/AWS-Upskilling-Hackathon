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

# TODO: Add these outputs as resources are created:
# output "bedrock_kb_id" {
#   description = "Bedrock Knowledge Base ID (Team 2 needs this for agent tool-use)"
#   value       = aws_bedrockagent_knowledge_base.main.id
# }
#
# output "bedrock_kb_arn" {
#   description = "Bedrock Knowledge Base ARN"
#   value       = aws_bedrockagent_knowledge_base.main.arn
# }
