output "lambda_function_name" {
  description = "Name of the verification Lambda — invoke to test endpoints"
  value       = aws_lambda_function.verify_endpoints.function_name
}

output "invoke_command" {
  description = "Command to run the verification"
  value       = "aws lambda invoke --function-name ${aws_lambda_function.verify_endpoints.function_name} --profile hackathon /dev/stdout"
}
