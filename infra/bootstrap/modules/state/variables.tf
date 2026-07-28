variable "bucket_name" {
  description = "Globally unique S3 bucket name."
  type        = string
  nullable    = false
}

variable "noncurrent_version_retention_days" {
  description = "Days to retain noncurrent state versions."
  type        = number
  nullable    = false

  validation {
    condition     = var.noncurrent_version_retention_days >= 90
    error_message = "Noncurrent state versions must be retained for at least 90 days."
  }
}

variable "tags" {
  description = "Mandatory project tags."
  type        = map(string)
  nullable    = false
}
