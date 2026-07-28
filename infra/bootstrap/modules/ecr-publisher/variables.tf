variable "ecr_repository_arn" {
  description = "Exact private ECR repository ARN the publisher may access."
  type        = string
  nullable    = false
}

variable "github_oidc_provider_arn" {
  description = "Exact GitHub Actions OIDC provider ARN trusted by the publisher."
  type        = string
  nullable    = false
}

variable "github_subject" {
  description = "Exact repository and sandbox environment-bound OIDC subject."
  type        = string
  nullable    = false

  validation {
    condition = (
      !strcontains(var.github_subject, "*") &&
      can(regex("^repo:[^:]+:environment:sandbox$", var.github_subject))
    )
    error_message = "github_subject must be one exact sandbox environment subject without wildcards."
  }
}

variable "role_name" {
  description = "Name of the sandbox image-publisher role."
  type        = string
  nullable    = false
}

variable "tags" {
  description = "Mandatory project tags."
  type        = map(string)
  nullable    = false
}
