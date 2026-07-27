resource "aws_lb" "this" {
  drop_invalid_header_fields = true
  enable_deletion_protection = false
  internal                   = false
  load_balancer_type         = "application"
  name                       = var.name
  region                     = var.region
  security_groups            = [var.security_group_id]
  subnets                    = var.subnet_ids

  tags = var.tags
}

resource "aws_lb_target_group" "application" {
  deregistration_delay = 30
  name                 = var.name
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
    path                = var.health_check_path
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
    target_group_arn = aws_lb_target_group.application.arn
  }

  tags = var.tags
}
