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
      output.ecr_repository_url == null &&
      output.ecs_cluster_name == null &&
      output.ecs_service_name == null &&
      output.alb_dns_name == null &&
      output.log_group_name == null &&
      output.task_execution_role_arn == null &&
      output.application_task_role_arn == null
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
    target = module.network[0].aws_security_group.task
    values = {
      id = "sg-22222222"
    }
  }

  variables {
    container_image    = "111122223333.dkr.ecr.us-east-1.amazonaws.com/fixture@sha256:0000000000000000000000000000000000000000000000000000000000000001"
    deployment_enabled = true
    ecr_repository_arn = "arn:aws:ecr:us-east-1:111122223333:repository/fixture"
    ecr_repository_url = "111122223333.dkr.ecr.us-east-1.amazonaws.com/fixture"
  }

  assert {
    condition     = toset(module.network[0].test_contract.subnet_zones) == toset(["us-east-1a", "us-east-1b"])
    error_message = "Enabled sandbox must use two distinct Availability Zones."
  }

  assert {
    condition = (
      module.network[0].test_contract.task_ingress_cidr == null &&
      module.network[0].test_contract.task_ingress_source_id == module.network[0].test_contract.alb_security_group_id &&
      module.network[0].test_contract.task_ingress_group_id == module.network[0].test_contract.task_security_group_id &&
      module.network[0].test_contract.alb_egress_group_id == module.network[0].test_contract.task_security_group_id &&
      module.network[0].test_contract.alb_egress_port == 8080
    )
    error_message = "Task ingress must reference only the ALB security group."
  }

  assert {
    condition     = module.iam[0].application_permissions == []
    error_message = "The application task role must have no permissions."
  }

  assert {
    condition = (
      jsondecode(module.iam[0].test_contract.application_trust_policy).Statement[0].Principal.Service == "ecs-tasks.amazonaws.com" &&
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
    condition = (
      module.ecs[0].test_contract.circuit_breaker_enabled &&
      module.ecs[0].test_contract.circuit_breaker_rollback
    )
    error_message = "ECS circuit breaker and automatic rollback must be enabled."
  }

  assert {
    condition     = module.alb[0].test_contract.health_check_path == "/ready"
    error_message = "The target group must use the readiness endpoint."
  }

  assert {
    condition     = module.ecs[0].test_contract.desired_count == 1
    error_message = "The sandbox service must default to one task."
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
      module.ecs[0].test_contract.container_definition.readonlyRootFilesystem &&
      !module.ecs[0].test_contract.container_definition.privileged &&
      module.ecs[0].test_contract.container_definition.user == "1000" &&
      module.ecs[0].test_contract.container_definition.linuxParameters.capabilities.drop == ["ALL"]
    )
    error_message = "The application container must retain its runtime hardening."
  }

  assert {
    condition = (
      output.ecr_repository_url == var.ecr_repository_url &&
      module.network[0].test_contract.resource_count +
      module.iam[0].test_contract.resource_count +
      module.alb[0].test_contract.resource_count +
      module.ecs[0].test_contract.resource_count +
      module.observability[0].test_contract.resource_count == 26
    )
    error_message = "Enabled runtime must consume the external repository and manage exactly 26 resources."
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

run "reject_production_public_tasks" {
  command = plan

  variables {
    environment = "production"
  }

  expect_failures = [var.network_profile]
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
