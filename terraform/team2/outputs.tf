# =============================================================================
# Team 2 Outputs
# =============================================================================

output "ecs_cluster_arn" {
  description = "ECS cluster ARN"
  value       = module.compute.ecs_cluster_arn
}

output "ecr_repository_url" {
  description = "ECR repository URL for chat frontend"
  value       = module.compute.ecr_repository_url
}

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = aws_cognito_user_pool.main.id
}

output "cognito_user_pool_arn" {
  description = "Cognito User Pool ARN"
  value       = aws_cognito_user_pool.main.arn
}

output "cognito_app_client_id" {
  description = "Cognito app client ID (used by the ALB listener)"
  value       = aws_cognito_user_pool_client.chat_app.id
}

output "cognito_app_client_secret" {
  description = "Cognito app client secret"
  value       = aws_cognito_user_pool_client.chat_app.client_secret
  sensitive   = true
}

output "cognito_domain" {
  description = "Cognito hosted-UI domain"
  value       = aws_cognito_user_pool_domain.main.domain
}

output "chat_target_group_arn" {
  description = "ALB target group ARN for the chat frontend (ECS service attaches here)"
  value       = aws_lb_target_group.chat_frontend.arn
}

output "app_url" {
  description = "Internal app URL (ALB DNS)"
  value       = data.terraform_remote_state.shared.outputs.alb_dns_name
}
