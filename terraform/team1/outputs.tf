# =============================================================================
# Team 1 Outputs
# =============================================================================

output "ecs_cluster_arn" {
  description = "ECS cluster ARN"
  value       = module.compute.ecs_cluster_arn
}

output "ecr_repository_url" {
  description = "ECR repository URL — push Open WebUI image here before first deploy"
  value       = module.compute.ecr_repository_url
}

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID — register in Entra ID app as audience"
  value       = aws_cognito_user_pool.main.id
}

output "cognito_user_pool_client_id" {
  description = "Cognito App Client ID — used by ALB authenticator"
  value       = aws_cognito_user_pool_client.open_webui.id
}

output "cognito_domain" {
  description = "Cognito hosted UI domain prefix"
  value       = aws_cognito_user_pool_domain.main.domain
}

output "bedrock_agent_id" {
  description = "Bedrock Agent ID — set as BEDROCK_AGENT_ID env var in Open WebUI"
  value       = aws_bedrockagent_agent.main.agent_id
}

output "bedrock_agent_alias_id" {
  description = "Bedrock Agent Alias ID — set as BEDROCK_AGENT_ALIAS_ID env var"
  value       = aws_bedrockagent_agent_alias.live.agent_alias_id
}

output "app_url" {
  description = "Internal app URL (access from within VPN/private network)"
  value       = "https://${local.alb_dns_name}"
}
