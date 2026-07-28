output "ecr_repository_url" {
  description = "ECR URL for the bedrock-proxy image — push here before running terraform apply on the compute module"
  value       = aws_ecr_repository.proxy.repository_url
}
