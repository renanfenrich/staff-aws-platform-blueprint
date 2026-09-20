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

  application_port         = var.application_port
  application_subnet_cidrs = var.application_subnet_cidrs
  database_subnet_cidrs    = var.database_subnet_cidrs
  availability_zones       = var.availability_zones
  aws_region               = var.aws_region
  name                     = local.resource_name
  public_subnet_cidrs      = var.public_subnet_cidrs
  tags                     = local.mandatory_tags
  vpc_cidr                 = var.vpc_cidr
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

  ecr_repository_arn  = var.ecr_repository_arn
  database_secret_arn = module.database[0].master_secret_arn
  log_group_arn       = module.observability[0].log_group_arn
  name                = local.resource_name
  tags                = local.mandatory_tags
}

module "database" {
  count                      = var.deployment_enabled ? 1 : 0
  source                     = "./modules/database"
  aws_region                 = var.aws_region
  database_security_group_id = module.network[0].database_security_group_id
  database_subnet_ids        = module.network[0].database_subnet_ids
  name                       = local.resource_name
  tags                       = local.mandatory_tags
}

module "alb" {
  count  = var.deployment_enabled ? 1 : 0
  source = "./modules/alb"

  application_port  = var.application_port
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

  application_port           = var.application_port
  backend_role_arn           = module.iam[0].backend_role_arn
  backend_security_group_id  = module.network[0].backend_task_security_group_id
  backend_target_group_arn   = module.alb[0].backend_target_group_arn
  aws_region                 = var.aws_region
  container_image            = var.container_image
  desired_count              = var.desired_task_count
  execution_role_arn         = module.iam[0].execution_role_arn
  health_check_grace_period  = var.health_check_grace_period_seconds
  log_group_name             = module.observability[0].log_group_name
  name                       = local.resource_name
  frontend_role_arn          = module.iam[0].frontend_role_arn
  frontend_security_group_id = module.network[0].frontend_task_security_group_id
  frontend_target_group_arn  = module.alb[0].frontend_target_group_arn
  subnet_ids                 = module.network[0].application_subnet_ids
  tags                       = local.mandatory_tags
  task_cpu                   = var.task_cpu
  task_memory                = var.task_memory
  database_host              = module.database[0].address
  database_name              = module.database[0].database_name
  database_port              = module.database[0].port
  database_secret_arn        = module.database[0].master_secret_arn
  database_user              = module.database[0].username
  database_ssl_ca_path       = "/app/rds-ca/global-bundle.pem"

  depends_on = [module.alb]
}

module "migration" {
  count                = var.deployment_enabled ? 1 : 0
  source               = "./modules/migration"
  backend_role_arn     = module.iam[0].backend_role_arn
  aws_region           = var.aws_region
  container_image      = var.container_image
  database_host        = module.database[0].address
  database_name        = module.database[0].database_name
  database_port        = module.database[0].port
  database_secret_arn  = module.database[0].master_secret_arn
  database_user        = module.database[0].username
  database_ssl_ca_path = "/app/rds-ca/global-bundle.pem"
  execution_role_arn   = module.iam[0].execution_role_arn
  log_group_name       = module.observability[0].log_group_name
  name                 = local.resource_name
  tags                 = local.mandatory_tags
}
