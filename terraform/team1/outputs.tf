# =============================================================================
# Team 1 Outputs
# =============================================================================

output "ecs_cluster_arn" {
  description = "ECS cluster ARN"
  value       = module.compute.ecs_cluster_arn
}

output "ecr_repository_url" {
  description = "ECR repository URL for chat frontend"
  value       = module.compute.ecr_repository_url
}

# TODO: Add these outputs as resources are created:
# output "cognito_user_pool_id" {
#   description = "Cognito User Pool ID"
#   value       = aws_cognito_user_pool.main.id
# }
#
# output "app_url" {
#   description = "Internal app URL (ALB DNS)"
#   value       = data.terraform_remote_state.shared.outputs.alb_dns_name
# }
