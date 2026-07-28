output "ecs_cluster_id" {
  description = "ID of the ECS cluster"
  value       = aws_ecs_cluster.main.id
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.main.arn
}

output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = aws_ecr_repository.chat_frontend.repository_url
}

output "alb_dns_name" {
  description = "DNS name of the internal ALB"
  value       = aws_lb.internal.dns_name
}

output "alb_arn" {
  description = "ARN of the internal ALB"
  value       = aws_lb.internal.arn
}

output "ecs_tasks_security_group_id" {
  description = "Security group ID for ECS tasks"
  value       = aws_security_group.ecs_tasks.id
}

output "ecs_task_role_arn" {
  description = "IAM task role ARN — the running containers assume this to call Bedrock"
  value       = aws_iam_role.ecs_task_role.arn
}

output "proxy_ecr_repository_url" {
  description = "ECR URL for the bedrock-proxy image (empty string if module not wired)"
  value       = ""
}
