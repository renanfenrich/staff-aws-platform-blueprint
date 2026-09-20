mock_provider "aws" {
  mock_resource "aws_cloudwatch_log_group" {
    defaults = {
      arn = "arn:aws:logs:us-east-1:111122223333:log-group:/ecs/fixture"
    }
  }

  mock_resource "aws_ecs_task_definition" {
    defaults = {
      arn = "arn:aws:ecs:us-east-1:111122223333:task-definition/fixture:1"
    }
  }

  mock_resource "aws_db_instance" {
    defaults = {
      address            = "fixture.cluster.us-east-1.rds.amazonaws.com"
      master_user_secret = [{ secret_arn = "arn:aws:secretsmanager:us-east-1:111122223333:secret:fixture" }]
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::111122223333:role/fixture"
    }
  }

  mock_resource "aws_lb" {
    defaults = {
      arn      = "arn:aws:elasticloadbalancing:us-east-1:111122223333:loadbalancer/app/fixture/1111111111111111"
      dns_name = "fixture.us-east-1.elb.amazonaws.com"
    }
  }

  mock_resource "aws_lb_target_group" {
    defaults = {
      arn = "arn:aws:elasticloadbalancing:us-east-1:111122223333:targetgroup/fixture/1111111111111111"
    }
  }

  mock_resource "aws_lb_listener" {
    defaults = {
      arn = "arn:aws:elasticloadbalancing:us-east-1:111122223333:listener/app/fixture/1111111111111111/2222222222222222"
    }
  }
}

variables {
  cost_center = "portfolio"
  owner       = "terraform-test"
}

run "disabled_mode_has_no_resources" {
  command = plan

  assert {
    condition = (
      length(module.network) == 0 &&
      length(module.database) == 0 &&
      length(module.migration) == 0 &&
      length(module.iam) == 0 &&
      length(module.alb) == 0 &&
      length(module.ecs) == 0 &&
      length(module.observability) == 0
    )
    error_message = "Disabled mode must not instantiate any AWS resource module."
  }

  assert {
    condition = (
      output.vpc_id == null &&
      output.public_subnet_ids == [] &&
      output.application_subnet_ids == [] &&
      output.database_subnet_ids == [] &&
      output.database_endpoint == null &&
      output.master_secret_arn == null &&
      output.interface_endpoint_ids == [] &&
      output.endpoint_security_group_id == null &&
      output.ecr_repository_url == null &&
      output.ecs_cluster_name == null &&
      output.frontend_ecs_service_name == null &&
      output.backend_ecs_service_name == null &&
      output.alb_dns_name == null &&
      output.log_group_name == null &&
      output.task_execution_role_arn == null &&
      output.frontend_task_role_arn == null &&
      output.backend_task_role_arn == null
    )
    error_message = "Disabled outputs must remain null or empty."
  }
}

run "enabled_sandbox_runtime" {
  command = apply

  override_resource {
    target = module.network[0].aws_security_group.alb
    values = {
      id = "sg-11111111"
    }
  }

  override_resource {
    target = module.network[0].aws_security_group.endpoint
    values = {
      id = "sg-33333333"
    }
  }

  override_resource {
    target = module.network[0].aws_security_group.frontend
    values = {
      id = "sg-22222222"
    }
  }

  override_resource {
    target = module.network[0].aws_security_group.backend
    values = {
      id = "sg-44444444"
    }
  }

  override_resource {
    target = module.iam[0].aws_iam_role.frontend
    values = {
      arn = "arn:aws:iam::111122223333:role/frontend-fixture"
    }
  }

  override_resource {
    target = module.iam[0].aws_iam_role.backend
    values = {
      arn = "arn:aws:iam::111122223333:role/backend-fixture"
    }
  }

  override_resource {
    target = module.alb[0].aws_lb_target_group.frontend
    values = {
      arn = "arn:aws:elasticloadbalancing:us-east-1:111122223333:targetgroup/frontend-fixture/1111111111111111"
    }
  }

  override_resource {
    target = module.alb[0].aws_lb_target_group.backend
    values = {
      arn = "arn:aws:elasticloadbalancing:us-east-1:111122223333:targetgroup/backend-fixture/2222222222222222"
    }
  }

  override_resource {
    target = module.migration[0].aws_ecs_task_definition.migration
    values = {
      task_role_arn = "arn:aws:iam::111122223333:role/backend-fixture"
    }
  }

  variables {
    container_image    = "111122223333.dkr.ecr.us-east-1.amazonaws.com/fixture@sha256:0000000000000000000000000000000000000000000000000000000000000001"
    deployment_enabled = true
    ecr_repository_arn = "arn:aws:ecr:us-east-1:111122223333:repository/fixture"
    ecr_repository_url = "111122223333.dkr.ecr.us-east-1.amazonaws.com/fixture"
  }

  assert {
    condition = (
      length(module.network[0].test_contract.public_subnet_ids) == 2 &&
      length(module.network[0].test_contract.application_subnet_ids) == 2 &&
      toset(module.network[0].test_contract.public_subnet_zones) == toset(["us-east-1a", "us-east-1b"]) &&
      toset(module.network[0].test_contract.application_subnet_zones) == toset(["us-east-1a", "us-east-1b"])
    )
    error_message = "ALB and ECS placement must each span the two configured Availability Zones."
  }

  assert {
    condition = (
      module.network[0].test_contract.application_default_route_count == 0 &&
      module.network[0].test_contract.interface_endpoint_count == 4 &&
      module.network[0].test_contract.database_default_route_count == 0
    )
    error_message = "Application and database route tables must have no internet default route and P4 must have exactly four interface endpoints."
  }

  assert {
    condition = (
      module.network[0].test_contract.interface_endpoints.ecr_api.private_dns_enabled &&
      module.network[0].test_contract.interface_endpoints.ecr_dkr.private_dns_enabled &&
      module.network[0].test_contract.interface_endpoints.logs.private_dns_enabled &&
      module.network[0].test_contract.interface_endpoints.secretsmanager.private_dns_enabled &&
      module.network[0].test_contract.interface_endpoints.ecr_api.service_name == "com.amazonaws.us-east-1.ecr.api" &&
      module.network[0].test_contract.interface_endpoints.ecr_dkr.service_name == "com.amazonaws.us-east-1.ecr.dkr" &&
      module.network[0].test_contract.interface_endpoints.logs.service_name == "com.amazonaws.us-east-1.logs" &&
      module.network[0].test_contract.interface_endpoints.secretsmanager.service_name == "com.amazonaws.us-east-1.secretsmanager" &&
      toset(module.network[0].test_contract.interface_endpoints.ecr_api.subnet_ids) == toset(module.network[0].test_contract.application_subnet_ids) &&
      toset(module.network[0].test_contract.interface_endpoints.ecr_dkr.subnet_ids) == toset(module.network[0].test_contract.application_subnet_ids) &&
      toset(module.network[0].test_contract.interface_endpoints.logs.subnet_ids) == toset(module.network[0].test_contract.application_subnet_ids) &&
      toset(module.network[0].test_contract.interface_endpoints.ecr_api.security_group_ids) == toset([module.network[0].test_contract.endpoint_security_group_id]) &&
      toset(module.network[0].test_contract.interface_endpoints.ecr_dkr.security_group_ids) == toset([module.network[0].test_contract.endpoint_security_group_id]) &&
      toset(module.network[0].test_contract.interface_endpoints.logs.security_group_ids) == toset([module.network[0].test_contract.endpoint_security_group_id])
    )
    error_message = "P4 interface endpoints must include the private Secrets Manager path."
  }

  assert {
    condition     = toset(module.network[0].test_contract.s3_route_table_ids) == toset(module.network[0].test_contract.application_route_table_ids)
    error_message = "The S3 gateway endpoint must be associated only with application route tables."
  }

  assert {
    condition     = module.network[0].test_contract.s3_service_name == "com.amazonaws.us-east-1.s3"
    error_message = "The commercial S3 gateway endpoint must use its commercial service name."
  }

  assert {
    condition = (
      module.database[0].test_contract.engine == "postgres" &&
      module.database[0].test_contract.engine_version == "17.11" &&
      !module.database[0].test_contract.publicly_accessible &&
      module.database[0].test_contract.storage_encrypted &&
      module.database[0].test_contract.force_ssl.value == "1" &&
      toset(module.database[0].test_contract.database_subnet_ids) == toset(module.network[0].test_contract.database_subnet_ids)
    )
    error_message = "P4 must represent private encrypted PostgreSQL 17 with forced TLS in both database subnets."
  }

  assert {
    condition = (
      module.ecs[0].test_contract.backend.container_definition.image == module.migration[0].test_contract.container_definition.image &&
      module.migration[0].test_contract.container_definition.command == ["node", "dist/db/migrate.js"] &&
      module.migration[0].test_contract.container_definition.readonlyRootFilesystem &&
      !module.migration[0].test_contract.container_definition.privileged &&
      module.migration[0].test_contract.container_definition.user == "1000" &&
      module.migration[0].test_contract.container_definition.linuxParameters.capabilities.drop == ["ALL"]
    )
    error_message = "The one-off migration definition must reuse the immutable image and preserve container hardening."
  }

  assert {
    condition = (
      jsondecode(module.iam[0].test_contract.backend_trust_policy).Statement[0].Principal.Service == "ecs-tasks.amazonaws.com" &&
      jsondecode(module.iam[0].test_contract.execution_trust_policy).Statement[0].Principal.Service == "ecs-tasks.amazonaws.com"
    )
    error_message = "Both runtime roles must trust only ECS tasks."
  }

  assert {
    condition = toset(flatten([
      for statement in jsondecode(module.iam[0].execution_policy).Statement :
      statement.Action
      ])) == toset([
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ])
    error_message = "Execution-role actions must be limited to ECR pull and log delivery."
  }

  assert {
    condition = (
      jsondecode(module.iam[0].execution_policy).Statement[0].Resource == "*" &&
      jsondecode(module.iam[0].execution_policy).Statement[1].Resource == var.ecr_repository_arn &&
      jsondecode(module.iam[0].execution_policy).Statement[2].Resource == "${module.observability[0].log_group_arn}:*"
    )
    error_message = "Execution-role resources must be scoped except for the ECR authorization token."
  }

  assert {
    condition     = module.observability[0].test_contract.retention_in_days == 7
    error_message = "Sandbox log retention must default to seven days."
  }

  assert {
    condition = alltrue([
      for tags in [
        module.network[0].test_contract.mandatory_tags,
        module.iam[0].test_contract.mandatory_tags,
        module.alb[0].test_contract.mandatory_tags,
        module.ecs[0].test_contract.mandatory_tags,
        module.observability[0].test_contract.mandatory_tags
        ] : alltrue([
          for key in ["Project", "Environment", "ManagedBy", "Owner", "CostCenter"] :
          contains(keys(tags), key) && length(tags[key]) > 0
      ])
    ])
    error_message = "Mandatory tags must reach every resource module."
  }

  assert {
    condition = (
      output.ecr_repository_url == var.ecr_repository_url &&
      module.network[0].test_contract.resource_count +
      module.iam[0].test_contract.resource_count +
      module.alb[0].test_contract.resource_count +
      module.ecs[0].test_contract.resource_count +
      module.observability[0].test_contract.resource_count +
      module.database[0].test_contract.resource_count +
      module.migration[0].test_contract.resource_count == 67
    )
    error_message = "Enabled P5 runtime must consume the external repository and manage exactly 67 resources."
  }

  assert {
    condition = (
      module.alb[0].test_contract.default_target_group_arn == module.alb[0].test_contract.frontend_target_group_arn &&
      module.alb[0].test_contract.backend_rule_priority == 100 &&
      toset(module.alb[0].test_contract.backend_path_patterns) == toset(["/api", "/api/*"]) &&
      module.alb[0].test_contract.frontend_health_path == "/health" &&
      module.alb[0].test_contract.backend_health_path == "/ready" &&
      module.ecs[0].test_contract.frontend.desired_count == 1 &&
      module.ecs[0].test_contract.backend.desired_count == 1 &&
      module.ecs[0].test_contract.frontend.assign_public_ip == false &&
      module.ecs[0].test_contract.backend.assign_public_ip == false &&
      toset(module.ecs[0].test_contract.frontend.subnet_ids) == toset(module.network[0].test_contract.application_subnet_ids) &&
      toset(module.ecs[0].test_contract.backend.subnet_ids) == toset(module.network[0].test_contract.application_subnet_ids) &&
      toset(module.ecs[0].test_contract.frontend.security_group_ids) == toset([module.network[0].test_contract.frontend_task_security_group_id]) &&
      toset(module.ecs[0].test_contract.backend.security_group_ids) == toset([module.network[0].test_contract.backend_task_security_group_id]) &&
      module.ecs[0].test_contract.frontend.target_group_arn == module.alb[0].test_contract.frontend_target_group_arn &&
      module.ecs[0].test_contract.backend.target_group_arn == module.alb[0].test_contract.backend_target_group_arn &&
      module.ecs[0].test_contract.frontend.circuit_breaker_enabled && module.ecs[0].test_contract.frontend.circuit_breaker_rollback &&
      module.ecs[0].test_contract.backend.circuit_breaker_enabled && module.ecs[0].test_contract.backend.circuit_breaker_rollback &&
      module.ecs[0].test_contract.frontend.role_arn == module.iam[0].frontend_role_arn &&
      module.ecs[0].test_contract.backend.role_arn == module.iam[0].backend_role_arn &&
      module.ecs[0].test_contract.frontend.container_definition.command == ["node", "frontend/server.mjs"] &&
      module.ecs[0].test_contract.frontend.container_definition.image == module.ecs[0].test_contract.backend.container_definition.image &&
      module.ecs[0].test_contract.backend.container_definition.image == module.migration[0].test_contract.container_definition.image &&
      strcontains(join(" ", module.ecs[0].test_contract.frontend.container_definition.healthCheck.command), "/health") &&
      strcontains(join(" ", module.ecs[0].test_contract.backend.container_definition.healthCheck.command), "/health")
    )
    error_message = "P5 must route the frontend by default, route both API paths to the backend, and use one immutable transitional image."
  }

  assert {
    condition = (
      module.network[0].test_contract.frontend_task_security_group_id != module.network[0].test_contract.backend_task_security_group_id &&
      module.network[0].test_contract.frontend_alb_ingress.source_id == module.network[0].test_contract.alb_security_group_id &&
      module.network[0].test_contract.frontend_alb_ingress.group_id == module.network[0].test_contract.frontend_task_security_group_id &&
      module.network[0].test_contract.frontend_alb_ingress.from_port == 8080 && module.network[0].test_contract.frontend_alb_ingress.to_port == 8080 &&
      module.network[0].test_contract.backend_alb_ingress.source_id == module.network[0].test_contract.alb_security_group_id &&
      module.network[0].test_contract.backend_alb_ingress.group_id == module.network[0].test_contract.backend_task_security_group_id &&
      alltrue([for rule in values(module.network[0].test_contract.alb_to_workloads) : rule.source_id == module.network[0].test_contract.alb_security_group_id && rule.from_port == 8080 && rule.to_port == 8080]) &&
      toset([for rule in values(module.network[0].test_contract.alb_to_workloads) : rule.target_id]) == toset([module.network[0].test_contract.frontend_task_security_group_id, module.network[0].test_contract.backend_task_security_group_id]) &&
      length(module.network[0].test_contract.endpoint_egress) == 2 &&
      alltrue([for rule in values(module.network[0].test_contract.endpoint_egress) : rule.target_id == module.network[0].test_contract.endpoint_security_group_id && rule.from_port == 443 && rule.to_port == 443]) &&
      toset([for rule in values(module.network[0].test_contract.endpoint_egress) : rule.source_id]) == toset([module.network[0].test_contract.frontend_task_security_group_id, module.network[0].test_contract.backend_task_security_group_id]) &&
      length(module.network[0].test_contract.endpoint_ingress) == 2 &&
      alltrue([for rule in values(module.network[0].test_contract.endpoint_ingress) : rule.group_id == module.network[0].test_contract.endpoint_security_group_id && rule.from_port == 443 && rule.to_port == 443]) &&
      toset([for rule in values(module.network[0].test_contract.endpoint_ingress) : rule.source_id]) == toset([module.network[0].test_contract.frontend_task_security_group_id, module.network[0].test_contract.backend_task_security_group_id]) &&
      length(module.network[0].test_contract.s3_egress) == 2 && alltrue([for rule in values(module.network[0].test_contract.s3_egress) : rule.prefix_list_id == module.network[0].test_contract.s3_prefix_list_id && rule.from_port == 443 && rule.to_port == 443]) &&
      length(module.network[0].test_contract.dns_egress) == 4 &&
      module.network[0].test_contract.direct_workload_egress_rule_count == 0 &&
      module.network[0].test_contract.backend_database_egress.source_id == module.network[0].test_contract.backend_task_security_group_id &&
      module.network[0].test_contract.backend_database_egress.target_id == module.network[0].test_contract.database_security_group_id &&
      module.network[0].test_contract.backend_database_egress.from_port == 5432 && module.network[0].test_contract.backend_database_egress.to_port == 5432 &&
      module.network[0].test_contract.database_backend_ingress.group_id == module.network[0].test_contract.database_security_group_id &&
      module.network[0].test_contract.database_backend_ingress.source_id == module.network[0].test_contract.backend_task_security_group_id &&
      module.network[0].test_contract.database_backend_ingress.from_port == 5432 && module.network[0].test_contract.database_backend_ingress.to_port == 5432 &&
      module.iam[0].test_contract.frontend_permissions == [] &&
      jsondecode(module.iam[0].backend_policy).Statement[0].Action == ["secretsmanager:GetSecretValue"] &&
      jsondecode(module.iam[0].backend_policy).Statement[0].Resource == module.database[0].test_contract.managed_secret_arn
    )
    error_message = "P5 must isolate frontend and backend task roles and security groups while preserving exact backend secret access."
  }

  assert {
    condition = (
      !contains([for item in module.ecs[0].test_contract.frontend.container_definition.environment : item.name], "DATABASE_HOST") &&
      !contains([for item in module.ecs[0].test_contract.frontend.container_definition.environment : item.name], "DATABASE_PORT") &&
      !contains([for item in module.ecs[0].test_contract.frontend.container_definition.environment : item.name], "DATABASE_NAME") &&
      !contains([for item in module.ecs[0].test_contract.frontend.container_definition.environment : item.name], "DATABASE_USER") &&
      !contains([for item in module.ecs[0].test_contract.frontend.container_definition.environment : item.name], "DATABASE_SECRET_ARN") &&
      !contains([for item in module.ecs[0].test_contract.frontend.container_definition.environment : item.name], "DATABASE_SSL_CA_PATH") &&
      alltrue([for name in ["DATABASE_HOST", "DATABASE_PORT", "DATABASE_NAME", "DATABASE_USER", "DATABASE_SECRET_ARN", "AWS_REGION", "DATABASE_SSL_CA_PATH"] : contains([for item in module.ecs[0].test_contract.backend.container_definition.environment : item.name], name)]) &&
      module.migration[0].test_contract.task_role_arn == module.iam[0].backend_role_arn &&
      module.migration[0].test_contract.task_role_arn != module.iam[0].frontend_role_arn
    )
    error_message = "P5 frontend must contain no database configuration, while backend and migration retain the exact database role contract."
  }
}

run "reject_latest_image" {
  command = plan

  variables {
    container_image    = "example.invalid/api:latest"
    deployment_enabled = true
    ecr_repository_arn = "arn:aws:ecr:us-east-1:111122223333:repository/fixture"
    ecr_repository_url = "111122223333.dkr.ecr.us-east-1.amazonaws.com/fixture"
  }

  expect_failures = [var.container_image]
}

run "reject_cross_repository_image" {
  command = plan

  variables {
    container_image    = "111122223333.dkr.ecr.us-east-1.amazonaws.com/other@sha256:0000000000000000000000000000000000000000000000000000000000000001"
    deployment_enabled = true
    ecr_repository_arn = "arn:aws:ecr:us-east-1:111122223333:repository/fixture"
    ecr_repository_url = "111122223333.dkr.ecr.us-east-1.amazonaws.com/fixture"
  }

  expect_failures = [var.container_image]
}

run "reject_mutable_image_reference" {
  command = plan

  variables {
    container_image    = "111122223333.dkr.ecr.us-east-1.amazonaws.com/fixture:develop"
    deployment_enabled = true
    ecr_repository_arn = "arn:aws:ecr:us-east-1:111122223333:repository/fixture"
    ecr_repository_url = "111122223333.dkr.ecr.us-east-1.amazonaws.com/fixture"
  }

  expect_failures = [var.container_image]
}

run "reject_mismatched_repository_identity" {
  command = plan

  variables {
    container_image    = "111122223333.dkr.ecr.us-east-1.amazonaws.com/fixture@sha256:0000000000000000000000000000000000000000000000000000000000000001"
    deployment_enabled = true
    ecr_repository_arn = "arn:aws:ecr:us-east-1:111122223333:repository/other"
    ecr_repository_url = "111122223333.dkr.ecr.us-east-1.amazonaws.com/fixture"
  }

  expect_failures = [check.external_ecr_repository_identity]
}

run "reject_repository_partition_mismatch" {
  command = plan

  variables {
    container_image    = "111122223333.dkr.ecr.cn-north-1.amazonaws.com/fixture@sha256:0000000000000000000000000000000000000000000000000000000000000001"
    deployment_enabled = true
    ecr_repository_arn = "arn:aws-cn:ecr:cn-north-1:111122223333:repository/fixture"
    ecr_repository_url = "111122223333.dkr.ecr.cn-north-1.amazonaws.com/fixture"
  }

  expect_failures = [check.external_ecr_repository_identity]
}

run "accept_govcloud_endpoint_names" {
  command = apply

  variables {
    availability_zones = ["us-gov-west-1a", "us-gov-west-1b"]
    aws_region         = "us-gov-west-1"
    container_image    = "111122223333.dkr.ecr.us-gov-west-1.amazonaws.com/fixture@sha256:0000000000000000000000000000000000000000000000000000000000000001"
    deployment_enabled = true
    ecr_repository_arn = "arn:aws-us-gov:ecr:us-gov-west-1:111122223333:repository/fixture"
    ecr_repository_url = "111122223333.dkr.ecr.us-gov-west-1.amazonaws.com/fixture"
  }

  assert {
    condition = (
      module.network[0].test_contract.interface_endpoints.ecr_api.service_name == "com.amazonaws.us-gov-west-1.ecr.api" &&
      module.network[0].test_contract.interface_endpoints.ecr_dkr.service_name == "com.amazonaws.us-gov-west-1.ecr.dkr" &&
      module.network[0].test_contract.interface_endpoints.logs.service_name == "com.amazonaws.us-gov-west-1.logs" &&
      module.network[0].test_contract.interface_endpoints.secretsmanager.service_name == "com.amazonaws.us-gov-west-1.secretsmanager" &&
      module.network[0].test_contract.s3_service_name == "com.amazonaws.us-gov-west-1.s3"
    )
    error_message = "GovCloud endpoint service names must retain the commercial prefix."
  }
}

run "accept_china_endpoint_names" {
  command = apply

  variables {
    availability_zones = ["cn-north-1a", "cn-north-1b"]
    aws_region         = "cn-north-1"
    container_image    = "111122223333.dkr.ecr.cn-north-1.amazonaws.com.cn/fixture@sha256:0000000000000000000000000000000000000000000000000000000000000001"
    deployment_enabled = true
    ecr_repository_arn = "arn:aws-cn:ecr:cn-north-1:111122223333:repository/fixture"
    ecr_repository_url = "111122223333.dkr.ecr.cn-north-1.amazonaws.com.cn/fixture"
  }

  assert {
    condition = (
      module.network[0].test_contract.interface_endpoints.ecr_api.service_name == "cn.com.amazonaws.cn-north-1.ecr.api" &&
      module.network[0].test_contract.interface_endpoints.ecr_dkr.service_name == "cn.com.amazonaws.cn-north-1.ecr.dkr" &&
      module.network[0].test_contract.interface_endpoints.logs.service_name == "com.amazonaws.cn-north-1.logs" &&
      module.network[0].test_contract.interface_endpoints.secretsmanager.service_name == "com.amazonaws.cn-north-1.secretsmanager" &&
      module.network[0].test_contract.s3_service_name == "com.amazonaws.cn-north-1.s3"
    )
    error_message = "China ECR uses China endpoint names while Logs and S3 retain their service names."
  }
}

run "reject_invalid_fargate_size" {
  command = plan

  variables {
    task_cpu    = 256
    task_memory = 4096
  }

  expect_failures = [var.task_memory]
}

run "reject_overlapping_subnets" {
  command = plan

  variables {
    public_subnet_cidrs = ["10.42.0.0/24", "10.42.0.0/24"]
  }

  expect_failures = [var.public_subnet_cidrs]
}

run "reject_duplicate_application_subnets" {
  command = plan

  variables {
    application_subnet_cidrs = ["10.42.10.0/24", "10.42.10.0/24"]
  }

  expect_failures = [var.application_subnet_cidrs]
}

run "reject_application_subnet_outside_vpc" {
  command = plan

  variables {
    application_subnet_cidrs = ["10.43.10.0/24", "10.43.11.0/24"]
  }

  expect_failures = [var.application_subnet_cidrs]
}

run "reject_application_public_subnet_collision" {
  command = plan

  variables {
    application_subnet_cidrs = ["10.42.0.0/24", "10.42.11.0/24"]
  }

  expect_failures = [var.application_subnet_cidrs]
}
