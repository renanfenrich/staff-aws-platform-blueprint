output "application_permissions" {
  value = []
}

output "application_role_arn" {
  value = aws_iam_role.application.arn
}

output "execution_policy" {
  value = aws_iam_role_policy.execution.policy
}

output "execution_role_arn" {
  value = aws_iam_role.execution.arn
}

output "test_contract" {
  value = {
    application_trust_policy = aws_iam_role.application.assume_role_policy
    execution_trust_policy   = aws_iam_role.execution.assume_role_policy
    mandatory_tags           = aws_iam_role.execution.tags
    resource_count           = 3
  }
}
