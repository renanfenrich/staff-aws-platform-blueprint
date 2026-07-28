variable "existing_provider_arn" {
  description = "Existing GitHub Actions OIDC provider ARN, or null to create one."
  type        = string
  default     = null
  nullable    = true
}

variable "github_subject" {
  description = "Exact repository and environment-bound GitHub OIDC subject."
  type        = string
  nullable    = false

  validation {
    condition = (
      !strcontains(var.github_subject, "*") &&
      can(regex("^repo:[^:]+:environment:[^:]+$", var.github_subject))
    )
    error_message = "github_subject must be one exact environment-bound subject without wildcards."
  }
}

variable "role_name" {
  description = "Name of the sandbox state-access role."
  type        = string
  nullable    = false
}

variable "state_bucket_arn" {
  description = "ARN of the state bucket."
  type        = string
  nullable    = false
}

variable "state_key" {
  description = "Exact sandbox Terraform state object key."
  type        = string
  nullable    = false
}

variable "tags" {
  description = "Mandatory project tags."
  type        = map(string)
  nullable    = false
}
