output "repository_arn" {
  description = "ARN of the protected application image repository."
  value       = aws_ecr_repository.this.arn
}

output "repository_name" {
  description = "Name of the protected application image repository."
  value       = aws_ecr_repository.this.name
}

output "repository_url" {
  description = "Private ECR URL of the protected application image repository."
  value       = aws_ecr_repository.this.repository_url
}

output "test_contract" {
  description = "Security properties exposed for deterministic Terraform tests."
  value = {
    encryption_type      = aws_ecr_repository.this.encryption_configuration[0].encryption_type
    force_delete         = aws_ecr_repository.this.force_delete
    image_tag_mutability = aws_ecr_repository.this.image_tag_mutability
    lifecycle_policy     = aws_ecr_lifecycle_policy.this.policy
    mandatory_tags       = aws_ecr_repository.this.tags
    prevent_destroy      = true
    resource_count       = 2
    scan_on_push         = aws_ecr_repository.this.image_scanning_configuration[0].scan_on_push
  }
}
