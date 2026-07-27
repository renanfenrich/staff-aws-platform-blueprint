output "cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "service_name" {
  value = aws_ecs_service.application.name
}

output "test_contract" {
  value = {
    circuit_breaker_enabled  = aws_ecs_service.application.deployment_circuit_breaker[0].enable
    circuit_breaker_rollback = aws_ecs_service.application.deployment_circuit_breaker[0].rollback
    container_definition     = jsondecode(aws_ecs_task_definition.application.container_definitions)[0]
    desired_count            = aws_ecs_service.application.desired_count
    mandatory_tags           = aws_ecs_cluster.this.tags
  }
}
