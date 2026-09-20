output "cluster_name" {
  value = aws_ecs_cluster.this.name
}
output "frontend_service_name" {
  value = aws_ecs_service.frontend.name
}
output "backend_service_name" {
  value = aws_ecs_service.backend.name
}
output "test_contract" {

  value = {

    backend = {
      container_definition     = jsondecode(aws_ecs_task_definition.backend.container_definitions)[0],
      desired_count            = aws_ecs_service.backend.desired_count,
      assign_public_ip         = aws_ecs_service.backend.network_configuration[0].assign_public_ip,
      subnet_ids               = aws_ecs_service.backend.network_configuration[0].subnets,
      security_group_ids       = aws_ecs_service.backend.network_configuration[0].security_groups,
      target_group_arn         = one(aws_ecs_service.backend.load_balancer).target_group_arn,
      role_arn                 = aws_ecs_task_definition.backend.task_role_arn,
      circuit_breaker_enabled  = aws_ecs_service.backend.deployment_circuit_breaker[0].enable,
      circuit_breaker_rollback = aws_ecs_service.backend.deployment_circuit_breaker[0].rollback
    }

    frontend = {
      container_definition     = jsondecode(aws_ecs_task_definition.frontend.container_definitions)[0],
      desired_count            = aws_ecs_service.frontend.desired_count,
      assign_public_ip         = aws_ecs_service.frontend.network_configuration[0].assign_public_ip,
      subnet_ids               = aws_ecs_service.frontend.network_configuration[0].subnets,
      security_group_ids       = aws_ecs_service.frontend.network_configuration[0].security_groups,
      target_group_arn         = one(aws_ecs_service.frontend.load_balancer).target_group_arn,
      role_arn                 = aws_ecs_task_definition.frontend.task_role_arn,
      circuit_breaker_enabled  = aws_ecs_service.frontend.deployment_circuit_breaker[0].enable,
      circuit_breaker_rollback = aws_ecs_service.frontend.deployment_circuit_breaker[0].rollback
    }

    mandatory_tags = aws_ecs_cluster.this.tags

    resource_count           = 5
    container_definition     = jsondecode(aws_ecs_task_definition.backend.container_definitions)[0]
    desired_count            = aws_ecs_service.backend.desired_count
    assign_public_ip         = aws_ecs_service.backend.network_configuration[0].assign_public_ip
    subnet_ids               = aws_ecs_service.backend.network_configuration[0].subnets
    circuit_breaker_enabled  = aws_ecs_service.backend.deployment_circuit_breaker[0].enable
    circuit_breaker_rollback = aws_ecs_service.backend.deployment_circuit_breaker[0].rollback
  }
}
