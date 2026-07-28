output "alb_dns_name" {
  description = "Public ALB DNS name, or null when deployment is disabled."
  value       = try(module.alb[0].dns_name, null)
}

output "application_task_role_arn" {
  description = "Empty-by-default application task role ARN, or null when disabled."
  value       = try(module.iam[0].application_role_arn, null)
}

output "ecr_repository_url" {
  description = "Externally managed ECR repository URL, or null when deployment is disabled."
  value       = var.deployment_enabled ? var.ecr_repository_url : null
}

output "ecs_cluster_name" {
  description = "ECS cluster name, or null when deployment is disabled."
  value       = try(module.ecs[0].cluster_name, null)
}

output "ecs_service_name" {
  description = "ECS service name, or null when deployment is disabled."
  value       = try(module.ecs[0].service_name, null)
}

output "log_group_name" {
  description = "CloudWatch application log group name, or null when disabled."
  value       = try(module.observability[0].log_group_name, null)
}

output "public_subnet_ids" {
  description = "Public sandbox subnet IDs, or an empty list when disabled."
  value       = try(module.network[0].public_subnet_ids, [])
}

output "task_execution_role_arn" {
  description = "ECS task execution role ARN, or null when deployment is disabled."
  value       = try(module.iam[0].execution_role_arn, null)
}

output "vpc_id" {
  description = "Sandbox VPC ID, or null when deployment is disabled."
  value       = try(module.network[0].vpc_id, null)
}
