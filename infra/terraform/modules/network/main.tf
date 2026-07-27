locals {
  subnets = zipmap(var.availability_zones, var.public_subnet_cidrs)
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  region               = var.aws_region

  tags = merge(var.tags, { Name = "${var.name}-vpc" })
}

resource "aws_subnet" "public" {
  for_each = local.subnets

  availability_zone = each.key
  cidr_block        = each.value
  region            = var.aws_region
  vpc_id            = aws_vpc.this.id

  tags = merge(var.tags, {
    Name    = "${var.name}-public-${each.key}"
    Network = "public"
  })
}

resource "aws_internet_gateway" "this" {
  region = var.aws_region
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.name}-igw" })
}

resource "aws_route_table" "public" {
  region = var.aws_region
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.name}-public" })
}

resource "aws_route" "internet" {
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
  region                 = var.aws_region
  route_table_id         = aws_route_table.public.id
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  region         = var.aws_region
  route_table_id = aws_route_table.public.id
  subnet_id      = each.value.id
}

resource "aws_security_group" "alb" {
  description            = "Sandbox ALB ingress and task-only egress"
  name                   = "${var.name}-alb"
  region                 = var.aws_region
  revoke_rules_on_delete = true
  vpc_id                 = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.name}-alb" })
}

resource "aws_security_group" "task" {
  description            = "Fargate task ingress from ALB and restricted public egress"
  name                   = "${var.name}-task"
  region                 = var.aws_region
  revoke_rules_on_delete = true
  vpc_id                 = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.name}-task" })
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  cidr_ipv4         = "0.0.0.0/0"
  description       = "Sandbox HTTP entry point"
  from_port         = 80
  ip_protocol       = "tcp"
  region            = var.aws_region
  security_group_id = aws_security_group.alb.id
  to_port           = 80

  tags = merge(var.tags, { Name = "${var.name}-alb-http" })
}

resource "aws_vpc_security_group_egress_rule" "alb_to_task" {
  description                  = "Application traffic to Fargate tasks"
  from_port                    = var.application_port
  ip_protocol                  = "tcp"
  region                       = var.aws_region
  referenced_security_group_id = aws_security_group.task.id
  security_group_id            = aws_security_group.alb.id
  to_port                      = var.application_port

  tags = merge(var.tags, { Name = "${var.name}-alb-to-task" })
}

resource "aws_vpc_security_group_ingress_rule" "task_from_alb" {
  description                  = "Application traffic from the ALB only"
  from_port                    = var.application_port
  ip_protocol                  = "tcp"
  region                       = var.aws_region
  referenced_security_group_id = aws_security_group.alb.id
  security_group_id            = aws_security_group.task.id
  to_port                      = var.application_port

  tags = merge(var.tags, { Name = "${var.name}-task-from-alb" })
}

resource "aws_vpc_security_group_egress_rule" "task_https" {
  cidr_ipv4         = "0.0.0.0/0"
  description       = "HTTPS to ECR, CloudWatch Logs, and public AWS endpoints"
  from_port         = 443
  ip_protocol       = "tcp"
  region            = var.aws_region
  security_group_id = aws_security_group.task.id
  to_port           = 443

  tags = merge(var.tags, { Name = "${var.name}-task-https" })
}

resource "aws_vpc_security_group_egress_rule" "task_dns_udp" {
  cidr_ipv4         = "${cidrhost(var.vpc_cidr, 2)}/32"
  description       = "UDP DNS to the VPC resolver"
  from_port         = 53
  ip_protocol       = "udp"
  region            = var.aws_region
  security_group_id = aws_security_group.task.id
  to_port           = 53

  tags = merge(var.tags, { Name = "${var.name}-task-dns-udp" })
}

resource "aws_vpc_security_group_egress_rule" "task_dns_tcp" {
  cidr_ipv4         = "${cidrhost(var.vpc_cidr, 2)}/32"
  description       = "TCP DNS to the VPC resolver"
  from_port         = 53
  ip_protocol       = "tcp"
  region            = var.aws_region
  security_group_id = aws_security_group.task.id
  to_port           = 53

  tags = merge(var.tags, { Name = "${var.name}-task-dns-tcp" })
}
