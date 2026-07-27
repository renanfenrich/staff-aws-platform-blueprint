output "repository_arn" {
  value = aws_ecr_repository.this.arn
}

output "repository_url" {
  value = aws_ecr_repository.this.repository_url
}

output "test_contract" {
  value = {
    encryption_type      = aws_ecr_repository.this.encryption_configuration[0].encryption_type
    force_delete         = aws_ecr_repository.this.force_delete
    image_tag_mutability = aws_ecr_repository.this.image_tag_mutability
    lifecycle_rule_count = length(jsondecode(aws_ecr_lifecycle_policy.this.policy).rules)
    mandatory_tags       = aws_ecr_repository.this.tags
    scan_on_push         = aws_ecr_repository.this.image_scanning_configuration[0].scan_on_push
  }
}
