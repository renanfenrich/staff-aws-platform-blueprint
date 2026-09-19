output "task_definition_arn" { value = aws_ecs_task_definition.migration.arn }
output "test_contract" { value = { container_definition = jsondecode(aws_ecs_task_definition.migration.container_definitions)[0], resource_count = 1 } }
