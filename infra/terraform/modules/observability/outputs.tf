output "log_group_arn" {
  value = aws_cloudwatch_log_group.application.arn
}

output "log_group_name" {
  value = aws_cloudwatch_log_group.application.name
}

output "test_contract" {
  value = {
    mandatory_tags    = aws_cloudwatch_log_group.application.tags
    retention_in_days = aws_cloudwatch_log_group.application.retention_in_days
  }
}
