variable "aws_region" {
  description = "AWS region for the disposable environment."
  type        = string
  default     = "us-east-1"
  nullable    = false
}

variable "cost_center" {
  description = "Cost allocation identifier applied to every resource."
  type        = string
  nullable    = false

  validation {
    condition     = length(trimspace(var.cost_center)) > 0
    error_message = "cost_center must not be empty."
  }
}

variable "deployment_enabled" {
  description = "Explicit cost gate. Resource modules will remain disabled unless true."
  type        = bool
  default     = false
  nullable    = false
}

variable "enable_waf" {
  description = "Create the optional WAF profile when the runtime slice exists."
  type        = bool
  default     = false
  nullable    = false
}

variable "environment" {
  description = "Deployment environment used for naming and policy boundaries."
  type        = string
  default     = "sandbox"
  nullable    = false

  validation {
    condition     = contains(["sandbox", "staging", "production"], var.environment)
    error_message = "environment must be sandbox, staging, or production."
  }
}

variable "github_repository" {
  description = "GitHub owner/repository allowed to use the future OIDC role."
  type        = string
  default     = "renanfenrich/staff-aws-platform-blueprint"
  nullable    = false

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "github_repository must use owner/repository format."
  }
}

variable "monthly_budget_usd" {
  description = "Monthly sandbox budget threshold in US dollars."
  type        = number
  default     = 25
  nullable    = false

  validation {
    condition     = var.monthly_budget_usd > 0
    error_message = "monthly_budget_usd must be greater than zero."
  }
}

variable "owner" {
  description = "Accountable owner applied to every resource."
  type        = string
  nullable    = false

  validation {
    condition     = length(trimspace(var.owner)) > 0
    error_message = "owner must not be empty."
  }
}

variable "persistence_profile" {
  description = "Persistence mode. The initial API remains stateless."
  type        = string
  default     = "none"
  nullable    = false

  validation {
    condition     = contains(["none", "efs"], var.persistence_profile)
    error_message = "persistence_profile must be none or efs."
  }
}

variable "project_name" {
  description = "Stable project identifier used for naming and tags."
  type        = string
  default     = "staff-aws-platform-blueprint"
  nullable    = false
}
