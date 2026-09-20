output "dns_name" { value = aws_lb.this.dns_name }
output "frontend_target_group_arn" { value = aws_lb_target_group.frontend.arn }
output "backend_target_group_arn" { value = aws_lb_target_group.backend.arn }
output "test_contract" {
  value = {
    frontend_target_group_arn = aws_lb_target_group.frontend.arn
    backend_target_group_arn  = aws_lb_target_group.backend.arn
    default_target_group_arn  = aws_lb_listener.http.default_action[0].target_group_arn
    frontend_health_path      = aws_lb_target_group.frontend.health_check[0].path
    backend_health_path       = aws_lb_target_group.backend.health_check[0].path
    backend_rule_priority     = aws_lb_listener_rule.backend_api.priority
    backend_path_patterns     = flatten([for condition in aws_lb_listener_rule.backend_api.condition : condition.path_pattern[*].values])
    mandatory_tags            = aws_lb.this.tags
    subnet_ids                = aws_lb.this.subnets
    resource_count            = 5
    health_check_path         = aws_lb_target_group.backend.health_check[0].path
  }
}
