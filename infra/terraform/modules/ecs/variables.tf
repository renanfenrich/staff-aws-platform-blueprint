variable "application_port" { type = number }
variable "aws_region" {
  type    = string
  default = "us-east-1"
}
variable "backend_role_arn" { type = string }
variable "backend_security_group_id" { type = string }
variable "backend_target_group_arn" { type = string }
variable "container_image" { type = string }
variable "database_host" { type = string }
variable "database_name" { type = string }
variable "database_port" { type = number }
variable "database_secret_arn" { type = string }
variable "database_ssl_ca_path" { type = string }
variable "database_user" { type = string }
variable "desired_count" { type = number }
variable "execution_role_arn" { type = string }
variable "frontend_role_arn" { type = string }
variable "frontend_security_group_id" { type = string }
variable "frontend_target_group_arn" { type = string }
variable "health_check_grace_period" { type = number }
variable "log_group_name" { type = string }
variable "name" { type = string }
variable "subnet_ids" { type = list(string) }
variable "tags" { type = map(string) }
variable "task_cpu" { type = number }
variable "task_memory" { type = number }
