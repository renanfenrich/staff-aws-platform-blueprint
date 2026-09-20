locals {
  frontend_name = "${substr(var.name, 0, 29)}-fe"
  backend_name  = "${substr(var.name, 0, 29)}-be"
}

resource "aws_lb" "this" {
  drop_invalid_header_fields = true
  enable_deletion_protection = false
  internal                   = false
  load_balancer_type         = "application"
  name                       = var.name
  region                     = var.region
  security_groups            = [var.security_group_id]
  subnets                    = var.subnet_ids
  tags                       = var.tags
}

resource "aws_lb_target_group" "frontend" {
  deregistration_delay = 30
  name                 = local.frontend_name
  port                 = var.application_port
  protocol             = "HTTP"
  region               = var.region
  target_type          = "ip"
  vpc_id               = var.vpc_id
  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200-399"
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 3
  }
  tags = var.tags
}

resource "aws_lb_target_group" "backend" {
  deregistration_delay = 30
  name                 = local.backend_name
  port                 = var.application_port
  protocol             = "HTTP"
  region               = var.region
  target_type          = "ip"
  vpc_id               = var.vpc_id
  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200-399"
    path                = "/ready"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 3
  }
  tags = var.tags
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"
  region            = var.region
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
  tags = var.tags
}

resource "aws_lb_listener_rule" "backend_api" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100
  region       = var.region
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
  condition {
    path_pattern {
      values = ["/api", "/api/*"]
    }
  }
  tags = var.tags
}
