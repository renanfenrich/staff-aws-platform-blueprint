variable "application_port" {
  type = number
}

variable "health_check_path" {
  type = string
}

variable "name" {
  type = string
}

variable "region" {
  type = string
}

variable "security_group_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "tags" {
  type = map(string)
}

variable "vpc_id" {
  type = string
}
