locals {
  mandatory_tags = {
    CostCenter  = var.cost_center
    Environment = var.environment
    ManagedBy   = "Terraform"
    Owner       = var.owner
    Project     = var.project_name
  }

  resource_name = "${substr(var.project_name, 0, 20)}-${var.environment}"
}

check "mandatory_tags" {
  assert {
    condition = alltrue([
      for value in values(local.mandatory_tags) : length(trimspace(value)) > 0
    ])
    error_message = "Every mandatory tag must have a non-empty value."
  }
}

check "external_ecr_repository_identity" {
  assert {
    condition = (
      !var.deployment_enabled ||
      try(
        split(":", var.ecr_repository_arn)[3] == split(".", split("/", var.ecr_repository_url)[0])[3] &&
        split(":", var.ecr_repository_arn)[4] == split(".", split("/", var.ecr_repository_url)[0])[0] &&
        trimprefix(split(":", var.ecr_repository_arn)[5], "repository/") == join("/", slice(
          split("/", var.ecr_repository_url),
          1,
          length(split("/", var.ecr_repository_url))
        )) &&
        (
          (
            split(":", var.ecr_repository_arn)[1] == "aws" &&
            !startswith(split(":", var.ecr_repository_arn)[3], "cn-") &&
            !startswith(split(":", var.ecr_repository_arn)[3], "us-gov-") &&
            !endswith(split("/", var.ecr_repository_url)[0], ".amazonaws.com.cn")
          ) ||
          (
            split(":", var.ecr_repository_arn)[1] == "aws-us-gov" &&
            startswith(split(":", var.ecr_repository_arn)[3], "us-gov-") &&
            !endswith(split("/", var.ecr_repository_url)[0], ".amazonaws.com.cn")
          ) ||
          (
            split(":", var.ecr_repository_arn)[1] == "aws-cn" &&
            startswith(split(":", var.ecr_repository_arn)[3], "cn-") &&
            endswith(split("/", var.ecr_repository_url)[0], ".amazonaws.com.cn")
          )
        ),
        false
      )
    )
    error_message = "ecr_repository_arn and ecr_repository_url must identify the same account, region, and repository."
  }
}

module "network" {
  count  = var.deployment_enabled ? 1 : 0
  source = "./modules/network"

  application_port    = var.application_port
  availability_zones  = var.availability_zones
  aws_region          = var.aws_region
  name                = local.resource_name
  public_subnet_cidrs = var.public_subnet_cidrs
  tags                = local.mandatory_tags
  vpc_cidr            = var.vpc_cidr
}

module "observability" {
  count  = var.deployment_enabled ? 1 : 0
  source = "./modules/observability"

  name              = local.resource_name
  region            = var.aws_region
  retention_in_days = var.log_retention_days
  tags              = local.mandatory_tags
}

module "iam" {
  count  = var.deployment_enabled ? 1 : 0
  source = "./modules/iam"

  ecr_repository_arn = var.ecr_repository_arn
  log_group_arn      = module.observability[0].log_group_arn
  name               = local.resource_name
  tags               = local.mandatory_tags
}

module "alb" {
  count  = var.deployment_enabled ? 1 : 0
  source = "./modules/alb"

  application_port  = var.application_port
  health_check_path = var.health_check_path
  name              = local.resource_name
  region            = var.aws_region
  security_group_id = module.network[0].alb_security_group_id
  subnet_ids        = module.network[0].public_subnet_ids
  tags              = local.mandatory_tags
  vpc_id            = module.network[0].vpc_id
}

module "ecs" {
  count  = var.deployment_enabled ? 1 : 0
  source = "./modules/ecs"

  application_port          = var.application_port
  application_role_arn      = module.iam[0].application_role_arn
  assign_public_ip          = var.network_profile == "sandbox-public"
  aws_region                = var.aws_region
  container_image           = var.container_image
  desired_count             = var.desired_task_count
  execution_role_arn        = module.iam[0].execution_role_arn
  health_check_grace_period = var.health_check_grace_period_seconds
  log_group_name            = module.observability[0].log_group_name
  name                      = local.resource_name
  security_group_id         = module.network[0].task_security_group_id
  subnet_ids                = module.network[0].public_subnet_ids
  tags                      = local.mandatory_tags
  target_group_arn          = module.alb[0].target_group_arn
  task_cpu                  = var.task_cpu
  task_memory               = var.task_memory

  depends_on = [module.alb]
}
