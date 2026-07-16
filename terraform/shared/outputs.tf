# These outputs are consumed by Team 1 and Team 2 via terraform_remote_state

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
