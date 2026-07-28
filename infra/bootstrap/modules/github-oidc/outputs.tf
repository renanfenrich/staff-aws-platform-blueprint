output "github_subject" {
  description = "Exact GitHub OIDC subject trusted by the role."
  value       = var.github_subject
}

output "provider_arn" {
  description = "Created or externally supplied OIDC provider ARN."
  value       = local.provider_arn
}

output "role_arn" {
  description = "Sandbox state-access role ARN."
  value       = aws_iam_role.state.arn
}

output "test_contract" {
  description = "Security properties exposed for deterministic Terraform tests."
  value = {
    audience                 = local.oidc_audience
    created_provider_count   = length(aws_iam_openid_connect_provider.github)
    github_oidc_url          = local.github_oidc_url
    lock_key                 = local.lock_key
    maximum_session_duration = aws_iam_role.state.max_session_duration
    resource_count           = 2 + length(aws_iam_openid_connect_provider.github)
    state_key                = var.state_key
    state_policy             = local.state_policy
    thumbprints_configured   = false
    trust_policy             = local.trust_policy
  }
}
