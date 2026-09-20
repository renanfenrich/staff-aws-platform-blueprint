variable "application_port" {
  type = number
}

variable "application_subnet_cidrs" {
  type = list(string)
}

variable "database_subnet_cidrs" { type = list(string) }

variable "availability_zones" {
  type = list(string)
}

variable "aws_region" {
  type = string
}

variable "name" {
  type = string
}

variable "public_subnet_cidrs" {
  type = list(string)
}

variable "tags" {
  type = map(string)
}

variable "vpc_cidr" {
  type = string
}
