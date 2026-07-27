# These outputs are consumed by Team 0 and Team 1 via terraform_remote_state

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

output "alb_http_listener_arn" {
  value = module.networking.alb_http_listener_arn
}

output "team0_developer_role_arn" {
  description = "IAM role ARN for Team 0 participants (Foundation / Ingestion)"
  value       = aws_iam_role.team0_developer.arn
}

output "team1_developer_role_arn" {
  description = "IAM role ARN for Team 1 participants (Access / Knowledge App)"
  value       = aws_iam_role.team1_developer.arn
}

output "team0_operator_role_arn" {
  description = "IAM role ARN for Team 0 organizers"
  value       = aws_iam_role.team0_operator.arn
}

output "aws_account_id" {
  description = "AWS account ID"
  value       = data.aws_caller_identity.current.account_id
}
