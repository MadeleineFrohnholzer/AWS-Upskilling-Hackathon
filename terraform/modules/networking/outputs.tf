# =============================================================================
# Outputs — consumed by Team 1 and Team 2 via terraform_remote_state
# =============================================================================

# VPC
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

# Subnets
output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = aws_subnet.private[*].id
}

# Security Groups
output "vpc_endpoints_security_group_id" {
  description = "Security group ID for VPC endpoints"
  value       = aws_security_group.vpc_endpoints.id
}

output "alb_security_group_id" {
  description = "Security group ID for the internal ALB"
  value       = aws_security_group.alb.id
}

output "lambda_security_group_id" {
  description = "Security group ID for Lambda functions"
  value       = aws_security_group.lambda.id
}

output "ecs_tasks_security_group_id" {
  description = "Security group ID for ECS Fargate tasks"
  value       = aws_security_group.ecs_tasks.id
}

# ALB
output "alb_arn" {
  description = "ARN of the internal ALB"
  value       = aws_lb.internal.arn
}

output "alb_dns_name" {
  description = "DNS name of the internal ALB"
  value       = aws_lb.internal.dns_name
}

output "alb_listener_arn" {
  description = "ARN of the default HTTP listener (Team 2 adds rules here)"
  value       = aws_lb_listener.http.arn
}

# VPC Endpoints (for reference/debugging)
output "endpoint_ids" {
  description = "Map of VPC endpoint service names to their IDs"
  value = {
    s3                    = aws_vpc_endpoint.s3.id
    dynamodb              = aws_vpc_endpoint.dynamodb.id
    bedrock_runtime       = aws_vpc_endpoint.bedrock_runtime.id
    bedrock_agent_runtime = aws_vpc_endpoint.bedrock_agent_runtime.id
    textract              = aws_vpc_endpoint.textract.id
    ecr_api               = aws_vpc_endpoint.ecr_api.id
    ecr_dkr               = aws_vpc_endpoint.ecr_dkr.id
    logs                  = aws_vpc_endpoint.logs.id
    sts                   = aws_vpc_endpoint.sts.id
  }
}
