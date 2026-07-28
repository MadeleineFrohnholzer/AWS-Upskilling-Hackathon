output "lambda_function_arn" {
  description = "Presigned URL generator Lambda ARN"
  value       = aws_lambda_function.presigned_url.arn
}

output "lambda_function_name" {
  description = "Presigned URL generator Lambda function name"
  value       = aws_lambda_function.presigned_url.function_name
}

output "api_endpoint" {
  description = "HTTP API Gateway invoke URL — POST /upload to get a presigned S3 PUT URL"
  value       = aws_apigatewayv2_stage.default.invoke_url
}
