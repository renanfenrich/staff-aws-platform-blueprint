variable "aws_region" { type = string }
variable "database_security_group_id" { type = string }
variable "database_subnet_ids" { type = list(string) }
variable "name" { type = string }
variable "tags" { type = map(string) }
