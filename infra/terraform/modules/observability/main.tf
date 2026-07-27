resource "aws_cloudwatch_log_group" "application" {
  name              = "/ecs/${var.name}"
  region            = var.region
  retention_in_days = var.retention_in_days

  tags = var.tags
}
