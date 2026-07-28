output "lambda_function_arn" {
  description = "Ingest Lambda ARN"
  value       = aws_lambda_function.ingest.arn
}

output "lambda_function_name" {
  description = "Ingest Lambda function name"
  value       = aws_lambda_function.ingest.function_name
}
