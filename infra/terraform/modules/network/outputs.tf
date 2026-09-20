output "alb_security_group_id" {
  value = aws_security_group.alb.id
}

output "public_subnet_ids" {
  value = [for zone in var.availability_zones : aws_subnet.public[zone].id]
}

output "application_subnet_ids" {
  value = [for zone in var.availability_zones : aws_subnet.application[zone].id]
}
output "database_subnet_ids" { value = [for zone in var.availability_zones : aws_subnet.database[zone].id] }
output "database_security_group_id" { value = aws_security_group.database.id }

output "interface_endpoint_ids" {
  value = [for service in sort(keys(aws_vpc_endpoint.interface)) : aws_vpc_endpoint.interface[service].id]
}

output "endpoint_security_group_id" {
  value = aws_security_group.endpoint.id
}

output "task_security_group_id" {
  value = aws_security_group.task.id
}

output "vpc_id" {
  value = aws_vpc.this.id
}

output "test_contract" {
  value = {
    alb_security_group_id       = aws_security_group.alb.id
    alb_egress_group_id         = aws_vpc_security_group_egress_rule.alb_to_task.referenced_security_group_id
    alb_egress_port             = aws_vpc_security_group_egress_rule.alb_to_task.from_port
    application_route_table_ids = [for zone in var.availability_zones : aws_route_table.application[zone].id]
    application_default_route_count = length(flatten([
      for route_table in values(aws_route_table.application) : [
        for route in route_table.route : route if try(route.cidr_block == "0.0.0.0/0", false)
      ]
    ]))
    application_subnet_ids       = [for zone in var.availability_zones : aws_subnet.application[zone].id]
    application_subnet_zones     = [for zone in var.availability_zones : aws_subnet.application[zone].availability_zone]
    database_subnet_ids          = [for zone in var.availability_zones : aws_subnet.database[zone].id]
    database_subnet_zones        = [for zone in var.availability_zones : aws_subnet.database[zone].availability_zone]
    database_route_table_ids     = [for zone in var.availability_zones : aws_route_table.database[zone].id]
    database_default_route_count = length(flatten([for table in values(aws_route_table.database) : [for route in table.route : route if try(route.cidr_block == "0.0.0.0/0", false)]]))
    database_security_group_id   = aws_security_group.database.id
    database_ingress_source_id   = aws_vpc_security_group_ingress_rule.database_from_task_postgres.referenced_security_group_id
    task_database_egress_id      = aws_vpc_security_group_egress_rule.task_to_database_postgres.referenced_security_group_id
    endpoint_ingress_source_id   = aws_vpc_security_group_ingress_rule.endpoint_from_task_https.referenced_security_group_id
    endpoint_security_group_id   = aws_security_group.endpoint.id
    interface_endpoints = {
      for service, endpoint in aws_vpc_endpoint.interface : service => {
        private_dns_enabled = endpoint.private_dns_enabled
        security_group_ids  = endpoint.security_group_ids
        service_name        = endpoint.service_name
        subnet_ids          = endpoint.subnet_ids
      }
    }
    mandatory_tags           = aws_vpc.this.tags
    interface_endpoint_count = length(aws_vpc_endpoint.interface)
    public_subnet_ids        = [for zone in var.availability_zones : aws_subnet.public[zone].id]
    public_subnet_zones      = [for zone in var.availability_zones : aws_subnet.public[zone].availability_zone]
    resource_count           = 39
    s3_prefix_list_id        = aws_vpc_endpoint.s3.prefix_list_id
    s3_route_table_ids       = aws_vpc_endpoint.s3.route_table_ids
    s3_service_name          = aws_vpc_endpoint.s3.service_name
    task_endpoint_egress_id  = aws_vpc_security_group_egress_rule.task_to_endpoint_https.referenced_security_group_id
    task_ingress_cidr        = aws_vpc_security_group_ingress_rule.task_from_alb.cidr_ipv4
    task_ingress_group_id    = aws_vpc_security_group_ingress_rule.task_from_alb.security_group_id
    task_ingress_source_id   = aws_vpc_security_group_ingress_rule.task_from_alb.referenced_security_group_id
    task_s3_prefix_list_id   = aws_vpc_security_group_egress_rule.task_to_s3_https.prefix_list_id
    task_security_group_id   = aws_security_group.task.id
  }
}
