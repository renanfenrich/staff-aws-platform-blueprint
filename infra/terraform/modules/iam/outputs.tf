output "backend_permissions" { value = ["secretsmanager:GetSecretValue"] }
output "backend_policy" { value = aws_iam_role_policy.backend_database_secret.policy }
output "frontend_permissions" { value = [] }
output "application_permissions" { value = ["secretsmanager:GetSecretValue"] }
output "application_policy" { value = aws_iam_role_policy.backend_database_secret.policy }
output "application_role_arn" { value = aws_iam_role.backend.arn }

output "backend_role_arn" {
  value = aws_iam_role.backend.arn
}

output "frontend_role_arn" {
  value = aws_iam_role.frontend.arn
}

output "execution_policy" {
  value = aws_iam_role_policy.execution.policy
}

output "execution_role_arn" {
  value = aws_iam_role.execution.arn
}

output "test_contract" {
  value = {
    backend_trust_policy     = aws_iam_role.backend.assume_role_policy
    execution_trust_policy   = aws_iam_role.execution.assume_role_policy
    frontend_permissions     = []
    frontend_trust_policy    = aws_iam_role.frontend.assume_role_policy
    mandatory_tags           = aws_iam_role.execution.tags
    resource_count           = 5
    application_trust_policy = aws_iam_role.backend.assume_role_policy
  }
}
