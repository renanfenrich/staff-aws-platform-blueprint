output "alb_security_group_id" {
  value = aws_security_group.alb.id
}

output "public_subnet_ids" {
  value = [for zone in var.availability_zones : aws_subnet.public[zone].id]
}

output "task_security_group_id" {
  value = aws_security_group.task.id
}

output "vpc_id" {
  value = aws_vpc.this.id
}

output "test_contract" {
  value = {
    alb_security_group_id  = aws_security_group.alb.id
    alb_egress_group_id    = aws_vpc_security_group_egress_rule.alb_to_task.referenced_security_group_id
    alb_egress_port        = aws_vpc_security_group_egress_rule.alb_to_task.from_port
    mandatory_tags         = aws_vpc.this.tags
    subnet_zones           = [for zone in var.availability_zones : aws_subnet.public[zone].availability_zone]
    task_ingress_cidr      = aws_vpc_security_group_ingress_rule.task_from_alb.cidr_ipv4
    task_ingress_group_id  = aws_vpc_security_group_ingress_rule.task_from_alb.security_group_id
    task_ingress_source_id = aws_vpc_security_group_ingress_rule.task_from_alb.referenced_security_group_id
    task_security_group_id = aws_security_group.task.id
  }
}
