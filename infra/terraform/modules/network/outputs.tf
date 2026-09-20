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
    frontend_alb_ingress_source_id  = aws_vpc_security_group_ingress_rule.frontend_from_alb.referenced_security_group_id,
    backend_alb_ingress_source_id   = aws_vpc_security_group_ingress_rule.backend_from_alb.referenced_security_group_id,
    frontend_alb_egress_id          = aws_vpc_security_group_egress_rule.alb_to_frontend.referenced_security_group_id,
    backend_alb_egress_id           = aws_vpc_security_group_egress_rule.alb_to_backend.referenced_security_group_id,
    backend_database_egress_id      = aws_vpc_security_group_egress_rule.backend_to_database_postgres.referenced_security_group_id,
    database_ingress_source_id      = aws_vpc_security_group_ingress_rule.database_from_backend_postgres.referenced_security_group_id,
    endpoint_security_group_id      = aws_security_group.endpoint.id,
    endpoint_ingress_sources        = [for key in sort(keys(aws_vpc_security_group_ingress_rule.endpoint_from_task_https)) : aws_vpc_security_group_ingress_rule.endpoint_from_task_https[key].referenced_security_group_id],
    task_endpoint_egress_ids        = [for key in sort(keys(aws_vpc_security_group_egress_rule.task_to_endpoint_https)) : aws_vpc_security_group_egress_rule.task_to_endpoint_https[key].referenced_security_group_id],
    task_s3_prefix_list_ids         = [for key in sort(keys(aws_vpc_security_group_egress_rule.task_to_s3_https)) : aws_vpc_security_group_egress_rule.task_to_s3_https[key].prefix_list_id],
    task_dns_rule_count             = length(aws_vpc_security_group_egress_rule.task_dns_tcp) + length(aws_vpc_security_group_egress_rule.task_dns_udp),
    application_subnet_ids          = [for zone in var.availability_zones : aws_subnet.application[zone].id],
    public_subnet_ids               = [for zone in var.availability_zones : aws_subnet.public[zone].id],
    database_subnet_ids             = [for zone in var.availability_zones : aws_subnet.database[zone].id],
    application_route_table_ids     = [for zone in var.availability_zones : aws_route_table.application[zone].id],
    database_route_table_ids        = [for zone in var.availability_zones : aws_route_table.database[zone].id],
    interface_endpoint_count        = length(aws_vpc_endpoint.interface),
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
    application_default_route_count = 0,
    database_default_route_count    = 0,
    mandatory_tags                  = aws_vpc.this.tags,
    public_subnet_zones             = [for zone in var.availability_zones : aws_subnet.public[zone].availability_zone],
    application_subnet_zones        = [for zone in var.availability_zones : aws_subnet.application[zone].availability_zone],
    database_subnet_zones           = [for zone in var.availability_zones : aws_subnet.database[zone].availability_zone],
    task_security_group_id          = aws_security_group.backend.id,
    task_endpoint_egress_id         = aws_security_group.endpoint.id,
    endpoint_ingress_source_id      = aws_security_group.backend.id,
    task_s3_prefix_list_id          = aws_vpc_endpoint.s3.prefix_list_id,
    task_ingress_cidr               = null,
    task_ingress_source_id          = aws_security_group.alb.id,
    task_ingress_group_id           = aws_security_group.backend.id,
    alb_egress_group_id             = aws_security_group.backend.id,
    alb_egress_port                 = var.application_port,
    task_database_egress_id         = aws_security_group.database.id,
    resource_count                  = 47
  }
}
