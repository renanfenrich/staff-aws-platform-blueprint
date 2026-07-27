locals {
  mandatory_tags = {
    CostCenter  = var.cost_center
    Environment = var.environment
    ManagedBy   = "Terraform"
    Owner       = var.owner
    Project     = var.project_name
  }
}

check "mandatory_tags" {
  assert {
    condition = alltrue([
      for value in values(local.mandatory_tags) : length(trimspace(value)) > 0
    ])
    error_message = "Every mandatory tag must have a non-empty value."
  }
}

# Foundation slice only: resources are deliberately introduced in later,
# reviewable modules. This root contract plans without AWS credentials and
# cannot incur cost.
