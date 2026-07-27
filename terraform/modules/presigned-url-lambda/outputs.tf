output "lambda_function_arn" {
  description = "Presigned URL generator Lambda ARN"
  value       = aws_lambda_function.presigned_url.arn
}

output "lambda_function_name" {
  description = "Presigned URL generator Lambda function name"
  value       = aws_lambda_function.presigned_url.function_name
}
