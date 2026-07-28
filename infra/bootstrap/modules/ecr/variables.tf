variable "name" {
  description = "Stable private ECR repository name."
  type        = string
}

variable "region" {
  description = "AWS region for the private ECR repository."
  type        = string
}

variable "tags" {
  description = "Mandatory project tags."
  type        = map(string)
}
