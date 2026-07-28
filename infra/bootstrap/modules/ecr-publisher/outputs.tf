output "role_arn" {
  description = "ARN of the sandbox image-publisher role."
  value       = aws_iam_role.publisher.arn
}

output "test_contract" {
  description = "Security properties exposed for deterministic Terraform tests."
  value = {
    audience                 = local.oidc_audience
    maximum_session_duration = aws_iam_role.publisher.max_session_duration
    publisher_policy         = local.publisher_policy
    resource_count           = 2
    role_name                = aws_iam_role.publisher.name
    trust_policy             = local.trust_policy
  }
}
