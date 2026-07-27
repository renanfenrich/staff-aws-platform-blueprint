output "dns_name" {
  value = aws_lb.this.dns_name
}

output "target_group_arn" {
  value = aws_lb_target_group.application.arn
}

output "test_contract" {
  value = {
    health_check_path = aws_lb_target_group.application.health_check[0].path
    mandatory_tags    = aws_lb.this.tags
  }
}
