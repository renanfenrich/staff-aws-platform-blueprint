output "foundation_contract" {
  description = "Validated inputs for later infrastructure modules."
  value = {
    aws_region          = var.aws_region
    deployment_enabled  = var.deployment_enabled
    enable_waf          = var.enable_waf
    environment         = var.environment
    github_repository   = var.github_repository
    monthly_budget_usd  = var.monthly_budget_usd
    persistence_profile = var.persistence_profile
    tags                = local.mandatory_tags
  }
}
