# =============================================================================
# Networking
# =============================================================================

output "vpc_id" {
  value = module.networking.vpc_id
}

output "vpc_cidr_block" {
  value = module.networking.vpc_cidr_block
}

output "public_subnet_ids" {
  value = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.networking.private_subnet_ids
}

output "alb_arn" {
  value = module.networking.alb_arn
}

output "alb_dns_name" {
  value = module.networking.alb_dns_name
}

output "alb_listener_arn" {
  value = module.networking.alb_listener_arn
}

output "alb_security_group_id" {
  value = module.networking.alb_security_group_id
}

output "lambda_security_group_id" {
  value = module.networking.lambda_security_group_id
}

output "ecs_tasks_security_group_id" {
  value = module.networking.ecs_tasks_security_group_id
}

output "endpoint_ids" {
  value = module.networking.endpoint_ids
}

# =============================================================================
# Storage / Ingestion
# =============================================================================

output "landing_bucket_id" {
  description = "S3 landing bucket name (for presigned URL generation)"
  value       = module.storage.landing_bucket_id
}

output "landing_bucket_arn" {
  description = "S3 landing bucket ARN"
  value       = module.storage.landing_bucket_arn
}

output "processed_bucket_id" {
  description = "S3 processed documents bucket name"
  value       = module.storage.processed_bucket_id
}

# output "presigned_url_lambda_name" {
#   description = "Presigned URL generator Lambda function name"
#   value       = module.presigned_url_lambda.lambda_function_name
# }

# output "upload_api_url" {
#   description = "HTTP API Gateway endpoint — POST /upload to request a presigned S3 PUT URL"
#   value       = module.presigned_url_lambda.api_endpoint
# }

# output "bedrock_kb_id" {
#   description = "Bedrock Knowledge Base ID"
#   value       = module.bedrock_kb.knowledge_base_id
# }

# output "bedrock_kb_arn" {
#   description = "Bedrock Knowledge Base ARN"
#   value       = module.bedrock_kb.knowledge_base_arn
# }

# =============================================================================
# Compute / App
# =============================================================================

# output "ecs_cluster_arn" {
#   description = "ECS cluster ARN"
#   value       = module.compute.ecs_cluster_arn
# }

# output "ecr_repository_url" {
#   description = "ECR repository URL for chat frontend"
#   value       = module.compute.ecr_repository_url
# }

# output "ecs_service_name" {
#   description = "ECS service name"
#   value       = aws_ecs_service.open_webui.name
# }

# output "chat_target_group_arn" {
#   description = "ALB target group ARN for the chat frontend"
#   value       = aws_lb_target_group.chat_frontend.arn
# }

output "app_url" {
  description = "Internal app URL (ALB DNS)"
  value       = module.networking.alb_dns_name
}

# output "bedrock_agent_id" {
#   description = "Bedrock Agent ID"
#   value       = module.bedrock_agent.agent_id
# }

# output "bedrock_agent_alias_id" {
#   description = "Bedrock Agent alias ID (live)"
#   value       = module.bedrock_agent.agent_alias_id
# }

# =============================================================================
# Cognito
# =============================================================================

# output "cognito_user_pool_id" {
#   description = "Cognito User Pool ID"
#   value       = aws_cognito_user_pool.main.id
# }

# output "cognito_user_pool_arn" {
#   description = "Cognito User Pool ARN"
#   value       = aws_cognito_user_pool.main.arn
# }

# output "cognito_app_client_id" {
#   description = "Cognito app client ID (used by the ALB listener)"
#   value       = aws_cognito_user_pool_client.chat_app.id
# }

# output "cognito_app_client_secret" {
#   description = "Cognito app client secret"
#   value       = aws_cognito_user_pool_client.chat_app.client_secret
#   sensitive   = true
# }

# output "cognito_domain" {
#   description = "Cognito hosted-UI domain"
#   value       = aws_cognito_user_pool_domain.main.domain
# }
