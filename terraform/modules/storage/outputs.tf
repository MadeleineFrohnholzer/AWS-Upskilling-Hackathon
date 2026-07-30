output "landing_bucket_id" {
  description = "ID of the landing S3 bucket"
  value       = aws_s3_bucket.landing.id
}

output "landing_bucket_arn" {
  description = "ARN of the landing S3 bucket"
  value       = aws_s3_bucket.landing.arn
}

output "processed_bucket_id" {
  description = "ID of the processed documents S3 bucket"
  value       = aws_s3_bucket.processed.id
}

output "processed_bucket_arn" {
  description = "ARN of the processed documents S3 bucket"
  value       = aws_s3_bucket.processed.arn
}

output "sessions_table_name" {
  description = "Name of the sessions DynamoDB table"
  value       = aws_dynamodb_table.sessions.name
}

output "sessions_table_arn" {
  description = "ARN of the sessions DynamoDB table"
  value       = aws_dynamodb_table.sessions.arn
}

output "feedback_table_name" {
  description = "Name of the feedback DynamoDB table"
  value       = aws_dynamodb_table.feedback.name
}

output "feedback_table_arn" {
  description = "ARN of the feedback DynamoDB table"
  value       = aws_dynamodb_table.feedback.arn
}

output "upload_audit_table_name" {
  description = "Name of the upload audit DynamoDB table"
  value       = aws_dynamodb_table.document_audit_trail.name
}

output "upload_audit_table_arn" {
  description = "ARN of the upload audit DynamoDB table"
  value       = aws_dynamodb_table.document_audit_trail.arn
}

output "chat_history_table_name" {
  description = "Name of the chat history DynamoDB table"
  value       = aws_dynamodb_table.chat_history.name
}

output "chat_history_table_arn" {
  description = "ARN of the chat history DynamoDB table"
  value       = aws_dynamodb_table.chat_history.arn
}
