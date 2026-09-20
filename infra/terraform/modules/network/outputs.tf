output "alb_security_group_id" {
  value = aws_security_group.alb.id
}
output "frontend_task_security_group_id" {
  value = aws_security_group.frontend.id
}
output "backend_task_security_group_id" {
  value = aws_security_group.backend.id
}
output "public_subnet_ids" {
  value = [for zone in var.availability_zones : aws_subnet.public[zone].id]
}
output "application_subnet_ids" {
  value = [for zone in var.availability_zones : aws_subnet.application[zone].id]
}
output "database_subnet_ids" {
  value = [for zone in var.availability_zones : aws_subnet.database[zone].id]
}
output "database_security_group_id" {
  value = aws_security_group.database.id
}
output "interface_endpoint_ids" {
  value = [for service in sort(keys(aws_vpc_endpoint.interface)) : aws_vpc_endpoint.interface[service].id]
}
output "endpoint_security_group_id" {
  value = aws_security_group.endpoint.id
}
output "vpc_id" {
  value = aws_vpc.this.id
}
output "test_contract" {
  value = {
    alb_security_group_id           = aws_security_group.alb.id,
    frontend_task_security_group_id = aws_security_group.frontend.id,
    backend_task_security_group_id  = aws_security_group.backend.id,
    database_security_group_id      = aws_security_group.database.id,
    frontend_alb_ingress = {
      from_port = aws_vpc_security_group_ingress_rule.frontend_from_alb.from_port
      to_port   = aws_vpc_security_group_ingress_rule.frontend_from_alb.to_port
      group_id  = aws_vpc_security_group_ingress_rule.frontend_from_alb.security_group_id
      source_id = aws_vpc_security_group_ingress_rule.frontend_from_alb.referenced_security_group_id
    }
    backend_alb_ingress = {
      from_port = aws_vpc_security_group_ingress_rule.backend_from_alb.from_port
      to_port   = aws_vpc_security_group_ingress_rule.backend_from_alb.to_port
      group_id  = aws_vpc_security_group_ingress_rule.backend_from_alb.security_group_id
      source_id = aws_vpc_security_group_ingress_rule.backend_from_alb.referenced_security_group_id
    }
    alb_to_workloads = {
      frontend = { from_port = aws_vpc_security_group_egress_rule.alb_to_frontend.from_port, to_port = aws_vpc_security_group_egress_rule.alb_to_frontend.to_port, source_id = aws_vpc_security_group_egress_rule.alb_to_frontend.security_group_id, target_id = aws_vpc_security_group_egress_rule.alb_to_frontend.referenced_security_group_id }
      backend  = { from_port = aws_vpc_security_group_egress_rule.alb_to_backend.from_port, to_port = aws_vpc_security_group_egress_rule.alb_to_backend.to_port, source_id = aws_vpc_security_group_egress_rule.alb_to_backend.security_group_id, target_id = aws_vpc_security_group_egress_rule.alb_to_backend.referenced_security_group_id }
    }
    endpoint_egress                   = { for key, rule in aws_vpc_security_group_egress_rule.task_to_endpoint_https : key => { from_port = rule.from_port, to_port = rule.to_port, source_id = rule.security_group_id, target_id = rule.referenced_security_group_id } }
    endpoint_ingress                  = { for key, rule in aws_vpc_security_group_ingress_rule.endpoint_from_task_https : key => { from_port = rule.from_port, to_port = rule.to_port, group_id = rule.security_group_id, source_id = rule.referenced_security_group_id } }
    s3_egress                         = { for key, rule in aws_vpc_security_group_egress_rule.task_to_s3_https : key => { from_port = rule.from_port, to_port = rule.to_port, source_id = rule.security_group_id, prefix_list_id = rule.prefix_list_id } }
    dns_egress                        = concat(values(aws_vpc_security_group_egress_rule.task_dns_tcp), values(aws_vpc_security_group_egress_rule.task_dns_udp))
    direct_workload_egress_rule_count = length([for rule in concat(values(aws_vpc_security_group_egress_rule.task_to_endpoint_https), [aws_vpc_security_group_egress_rule.backend_to_database_postgres]) : rule if contains([aws_security_group.frontend.id, aws_security_group.backend.id], rule.referenced_security_group_id)])
    backend_database_egress           = { from_port = aws_vpc_security_group_egress_rule.backend_to_database_postgres.from_port, to_port = aws_vpc_security_group_egress_rule.backend_to_database_postgres.to_port, source_id = aws_vpc_security_group_egress_rule.backend_to_database_postgres.security_group_id, target_id = aws_vpc_security_group_egress_rule.backend_to_database_postgres.referenced_security_group_id }
    database_backend_ingress          = { from_port = aws_vpc_security_group_ingress_rule.database_from_backend_postgres.from_port, to_port = aws_vpc_security_group_ingress_rule.database_from_backend_postgres.to_port, group_id = aws_vpc_security_group_ingress_rule.database_from_backend_postgres.security_group_id, source_id = aws_vpc_security_group_ingress_rule.database_from_backend_postgres.referenced_security_group_id }
    endpoint_security_group_id        = aws_security_group.endpoint.id,
    application_subnet_ids            = [for zone in var.availability_zones : aws_subnet.application[zone].id],
    public_subnet_ids                 = [for zone in var.availability_zones : aws_subnet.public[zone].id],
    database_subnet_ids               = [for zone in var.availability_zones : aws_subnet.database[zone].id],
    application_route_table_ids       = [for zone in var.availability_zones : aws_route_table.application[zone].id],
    database_route_table_ids          = [for zone in var.availability_zones : aws_route_table.database[zone].id],
    interface_endpoint_count          = length(aws_vpc_endpoint.interface),
    interface_endpoints = { for service, endpoint in aws_vpc_endpoint.interface :
      service => {
        private_dns_enabled = endpoint.private_dns_enabled,
        service_name        = endpoint.service_name,
        subnet_ids          = endpoint.subnet_ids,
        security_group_ids  = endpoint.security_group_ids
    } },
    s3_prefix_list_id               = aws_vpc_endpoint.s3.prefix_list_id,
    s3_route_table_ids              = aws_vpc_endpoint.s3.route_table_ids,
    s3_service_name                 = aws_vpc_endpoint.s3.service_name,
    application_default_route_count = length(flatten([for table in values(aws_route_table.application) : [for route in table.route : route if try(route.cidr_block == "0.0.0.0/0", false)]])),
    database_default_route_count    = length(flatten([for table in values(aws_route_table.database) : [for route in table.route : route if try(route.cidr_block == "0.0.0.0/0", false)]])),
    mandatory_tags                  = aws_vpc.this.tags,
    public_subnet_zones             = [for zone in var.availability_zones : aws_subnet.public[zone].availability_zone],
    application_subnet_zones        = [for zone in var.availability_zones : aws_subnet.application[zone].availability_zone],
    database_subnet_zones           = [for zone in var.availability_zones : aws_subnet.database[zone].availability_zone],
    resource_count                  = 47
  }
}
