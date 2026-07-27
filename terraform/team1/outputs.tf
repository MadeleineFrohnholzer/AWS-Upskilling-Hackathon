# =============================================================================
# Team 1 Outputs — consumed by Team 0 via terraform_remote_state
# =============================================================================

output "landing_bucket_id" {
  description = "S3 landing bucket name (for presigned URL generation)"
  value       = module.storage.landing_bucket_id
}

output "landing_bucket_arn" {
  description = "S3 landing bucket ARN"
  value       = module.storage.landing_bucket_arn
}

output "landing_bucket_name" {
  description = "S3 landing bucket name (alias for Team 0 citation presigned URLs)"
  value       = module.storage.landing_bucket_id
}

output "processed_bucket_id" {
  description = "S3 processed documents bucket name"
  value       = module.storage.processed_bucket_id
}

output "documents_table_name" {
  description = "DynamoDB documents catalog table name"
  value       = aws_dynamodb_table.documents.name
}

output "documents_table_arn" {
  description = "DynamoDB documents catalog table ARN"
  value       = aws_dynamodb_table.documents.arn
}

output "api_endpoint" {
  description = "Internal API Gateway base URL — POST /upload-url to get a presigned upload URL"
  value       = "${aws_api_gateway_stage.main.invoke_url}/upload-url"
}

output "bedrock_kb_id" {
  description = "Bedrock Knowledge Base ID — Team 0 plugs this into their Bedrock Agent tool-use config"
  value       = aws_bedrockagent_knowledge_base.main.id
}

output "bedrock_kb_arn" {
  description = "Bedrock Knowledge Base ARN"
  value       = aws_bedrockagent_knowledge_base.main.arn
}

output "bedrock_data_source_id" {
  description = "Bedrock KB data source ID — used to trigger manual ingestion sync jobs"
  value       = aws_bedrockagent_data_source.processed.data_source_id
}

output "s3_vector_store_arn" {
  description = "S3 Vector Store bucket ARN"
  value       = aws_s3_bucket.vector_store.arn
}

output "cloudwatch_dashboard_url" {
  description = "Direct link to the Team 1 CloudWatch dashboard"
  value       = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=${var.project_name}-team1"
}

output "alarm_sns_topic_arn" {
  description = "SNS topic ARN for CloudWatch alarms — confirm subscription email to receive alerts"
  value       = aws_sns_topic.alarms.arn
}

output "eventbridge_digest_schedule" {
  description = "Weekly digest EventBridge schedule expression"
  value       = aws_cloudwatch_event_rule.weekly_digest.schedule_expression
}
