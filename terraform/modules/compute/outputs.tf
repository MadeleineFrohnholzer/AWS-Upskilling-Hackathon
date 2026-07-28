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

output "cloudwatch_dashboard_name" {
  description = "CloudWatch dashboard name — open in console to view ECS + ALB metrics"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

output "alarm_arns" {
  description = "ARNs of the three CloudWatch metric alarms"
  value = {
    alb_5xx_rate    = aws_cloudwatch_metric_alarm.alb_5xx_rate.arn
    alb_latency_p95 = aws_cloudwatch_metric_alarm.alb_latency_p95.arn
    ecs_cpu         = aws_cloudwatch_metric_alarm.ecs_cpu.arn
  }
}
