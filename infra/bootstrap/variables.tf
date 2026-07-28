variable "aws_region" {
  description = "AWS region for the remote-state foundation."
  type        = string
  default     = "us-east-1"
  nullable    = false

  validation {
    condition     = can(regex("^[a-z]{2}(-gov)?-[a-z]+-[0-9]+$", var.aws_region))
    error_message = "aws_region must be a valid AWS region name."
  }
}

variable "bootstrap_enabled" {
  description = "Explicit cost gate. No AWS resources exist in the graph unless true."
  type        = bool
  default     = false
  nullable    = false
}

variable "cost_center" {
  description = "Cost allocation identifier applied to every taggable resource."
  type        = string
  nullable    = false

  validation {
    condition     = length(trimspace(var.cost_center)) > 0
    error_message = "cost_center must not be empty."
  }
}

variable "existing_github_oidc_provider_arn" {
  description = "Existing account-level GitHub Actions OIDC provider ARN, or null to create one."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition = (
      var.existing_github_oidc_provider_arn == null ||
      can(regex(
        "^arn:(aws|aws-us-gov|aws-cn):iam::[0-9]{12}:oidc-provider/token\\.actions\\.githubusercontent\\.com$",
        var.existing_github_oidc_provider_arn
      ))
    )
    error_message = "existing_github_oidc_provider_arn must be the ARN of the GitHub Actions IAM OIDC provider."
  }
}

variable "github_oidc_subject" {
  description = "Exact GitHub environment subject verified through the repository OIDC API."
  type        = string
  default     = "repo:renanfenrich@1413054/staff-aws-platform-blueprint@1314297578:environment:sandbox"
  nullable    = false

  validation {
    condition = (
      var.github_oidc_subject == "repo:renanfenrich@1413054/staff-aws-platform-blueprint@1314297578:environment:sandbox" &&
      !strcontains(var.github_oidc_subject, "*")
    )
    error_message = "github_oidc_subject must be the exact verified immutable sandbox environment subject."
  }
}

variable "owner" {
  description = "Accountable owner applied to every taggable resource."
  type        = string
  nullable    = false

  validation {
    condition     = length(trimspace(var.owner)) > 0
    error_message = "owner must not be empty."
  }
}

variable "state_bucket_name" {
  description = "Caller-supplied globally unique name for the Terraform state bucket."
  type        = string
  default     = ""
  nullable    = false

  validation {
    condition = (
      !var.bootstrap_enabled ||
      (
        length(var.state_bucket_name) >= 3 &&
        length(var.state_bucket_name) <= 63 &&
        can(regex("^[a-z0-9][a-z0-9.-]*[a-z0-9]$", var.state_bucket_name)) &&
        !strcontains(var.state_bucket_name, "..") &&
        !strcontains(var.state_bucket_name, ".-") &&
        !strcontains(var.state_bucket_name, "-.") &&
        !can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+$", var.state_bucket_name)) &&
        !startswith(var.state_bucket_name, "xn--") &&
        !startswith(var.state_bucket_name, "sthree-") &&
        !startswith(var.state_bucket_name, "amzn_s3_demo_") &&
        !endswith(var.state_bucket_name, "-s3alias") &&
        !endswith(var.state_bucket_name, "--ol-s3") &&
        !endswith(var.state_bucket_name, ".mrap") &&
        !endswith(var.state_bucket_name, "--x-s3") &&
        !endswith(var.state_bucket_name, "--table-s3")
      )
    )
    error_message = "state_bucket_name must meet current general-purpose S3 bucket naming rules when bootstrap is enabled."
  }
}
