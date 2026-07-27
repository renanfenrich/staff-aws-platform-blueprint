variable "application_port" {
  type = number
}

variable "application_role_arn" {
  type = string
}

variable "assign_public_ip" {
  type = bool
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "container_image" {
  type = string
}

variable "desired_count" {
  type = number
}

variable "execution_role_arn" {
  type = string
}

variable "health_check_grace_period" {
  type = number
}

variable "log_group_name" {
  type = string
}

variable "name" {
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

variable "target_group_arn" {
  type = string
}

variable "task_cpu" {
  type = number
}

variable "task_memory" {
  type = number
}
