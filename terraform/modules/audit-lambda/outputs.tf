output "function_name" {
  description = "Name of the audit Lambda function"
  value       = aws_lambda_function.audit.function_name
}

output "function_arn" {
  description = "ARN of the audit Lambda function"
  value       = aws_lambda_function.audit.arn
}
