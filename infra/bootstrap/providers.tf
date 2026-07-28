provider "aws" {
  region = var.aws_region

  # Disabled plans use non-secret local placeholders and must not call AWS.
  skip_credentials_validation = !var.bootstrap_enabled
  skip_metadata_api_check     = !var.bootstrap_enabled
  skip_region_validation      = !var.bootstrap_enabled
  skip_requesting_account_id  = !var.bootstrap_enabled
}
