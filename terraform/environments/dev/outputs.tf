output "vpc_id" {
  description = "VPC ID"
  value       = module.networking.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.networking.private_subnet_ids
}

output "landing_bucket_id" {
  description = "S3 landing bucket name"
  value       = module.storage.landing_bucket_id
}

output "ecs_cluster_arn" {
  description = "ECS cluster ARN"
  value       = module.compute.ecs_cluster_arn
}

output "alb_dns_name" {
  description = "Internal ALB DNS name"
  value       = module.compute.alb_dns_name
}

output "ecr_repository_url" {
  description = "ECR repository URL for chat frontend"
  value       = module.compute.ecr_repository_url
}
