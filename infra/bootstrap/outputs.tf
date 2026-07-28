output "ecr_repository_arn" {
  description = "Protected application image repository ARN, or null when disabled."
  value       = try(module.ecr[0].repository_arn, null)
}

output "ecr_repository_name" {
  description = "Protected application image repository name, or null when disabled."
  value       = try(module.ecr[0].repository_name, null)
}

output "ecr_repository_url" {
  description = "Protected application image repository URL, or null when disabled."
  value       = try(module.ecr[0].repository_url, null)
}

output "github_oidc_provider_arn" {
  description = "Created or externally supplied GitHub OIDC provider ARN, or null when disabled."
  value       = try(module.github_oidc[0].provider_arn, null)
}

output "github_oidc_subject" {
  description = "Exact GitHub OIDC subject trusted by the state role, or null when disabled."
  value       = try(module.github_oidc[0].github_subject, null)
}

output "image_publisher_role_arn" {
  description = "GitHub sandbox image-publisher role ARN, or null when disabled."
  value       = try(module.ecr_publisher[0].role_arn, null)
}

output "sandbox_state_role_arn" {
  description = "GitHub sandbox state-access role ARN, or null when disabled."
  value       = try(module.github_oidc[0].role_arn, null)
}

output "state_bucket_arn" {
  description = "Protected Terraform state bucket ARN, or null when disabled."
  value       = try(module.state[0].bucket_arn, null)
}

output "state_bucket_name" {
  description = "Protected Terraform state bucket name, or null when disabled."
  value       = try(module.state[0].bucket_name, null)
}
