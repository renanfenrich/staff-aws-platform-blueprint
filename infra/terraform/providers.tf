provider "aws" {
  region = var.aws_region

  # Disabled plans use non-secret local placeholders and must not call AWS.
  skip_credentials_validation = !var.deployment_enabled
  skip_metadata_api_check     = !var.deployment_enabled
  skip_region_validation      = !var.deployment_enabled
  skip_requesting_account_id  = !var.deployment_enabled
}
