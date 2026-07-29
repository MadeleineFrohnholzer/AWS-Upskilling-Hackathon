output "function_name" {
  description = "Name of the digest Lambda function"
  value       = aws_lambda_function.digest.function_name
}

output "function_arn" {
  description = "ARN of the digest Lambda function"
  value       = aws_lambda_function.digest.arn
}
