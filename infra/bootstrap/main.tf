locals {
  mandatory_tags = {
    CostCenter  = var.cost_center
    Environment = "sandbox"
    ManagedBy   = "Terraform"
    Owner       = var.owner
    Project     = "staff-aws-platform-blueprint"
  }

  sandbox_state_key = "staff-aws-platform-blueprint/sandbox/terraform.tfstate"
}

check "mandatory_tags" {
  assert {
    condition = alltrue([
      for value in values(local.mandatory_tags) : length(trimspace(value)) > 0
    ])
    error_message = "Every mandatory tag must have a non-empty value."
  }
}

module "state" {
  count  = var.bootstrap_enabled ? 1 : 0
  source = "./modules/state"

  bucket_name                       = var.state_bucket_name
  noncurrent_version_retention_days = 90
  tags                              = local.mandatory_tags
}

module "github_oidc" {
  count  = var.bootstrap_enabled ? 1 : 0
  source = "./modules/github-oidc"

  existing_provider_arn = var.existing_github_oidc_provider_arn
  github_subject        = var.github_oidc_subject
  role_name             = "staff-aws-platform-blueprint-sandbox-state"
  state_bucket_arn      = module.state[0].bucket_arn
  state_key             = local.sandbox_state_key
  tags                  = local.mandatory_tags
}
