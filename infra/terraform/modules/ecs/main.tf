locals {
  container_name = "api"
}

resource "aws_ecs_cluster" "this" {
  name   = var.name
  region = var.aws_region

  setting {
    name  = "containerInsights"
    value = "disabled"
  }

  tags = var.tags
}

resource "aws_ecs_task_definition" "application" {
  container_definitions = jsonencode([
    {
      name                   = local.container_name
      image                  = var.container_image
      essential              = true
      readonlyRootFilesystem = true
      privileged             = false
      user                   = "1000"
      cpu                    = var.task_cpu
      memory                 = var.task_memory
      stopTimeout            = 30
      portMappings = [{
        name          = "http"
        containerPort = var.application_port
        hostPort      = var.application_port
        protocol      = "tcp"
      }]
      environment = [
        {
          name  = "LOG_LEVEL"
          value = "info"
        },
        {
          name  = "NODE_ENV"
          value = "production"
        },
        {
          name  = "PORT"
          value = tostring(var.application_port)
        },
        {
          name  = "SHUTDOWN_TIMEOUT_MS"
          value = "25000"
        }
      ]
      healthCheck = {
        command = [
          "CMD-SHELL",
          "node -e \"fetch('http://127.0.0.1:${var.application_port}/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))\""
        ]
        interval    = 30
        retries     = 3
        startPeriod = 10
        timeout     = 5
      }
      linuxParameters = {
        initProcessEnabled = true
        capabilities = {
          add  = []
          drop = ["ALL"]
        }
      }
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = var.log_group_name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "api"
        }
      }
    }
  ])
  cpu                      = tostring(var.task_cpu)
  execution_role_arn       = var.execution_role_arn
  family                   = var.name
  memory                   = tostring(var.task_memory)
  network_mode             = "awsvpc"
  region                   = var.aws_region
  requires_compatibilities = ["FARGATE"]
  task_role_arn            = var.application_role_arn

  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }

  tags = var.tags
}

resource "aws_ecs_service" "application" {
  cluster                            = aws_ecs_cluster.this.id
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100
  desired_count                      = var.desired_count
  enable_ecs_managed_tags            = true
  health_check_grace_period_seconds  = var.health_check_grace_period
  launch_type                        = "FARGATE"
  name                               = var.name
  platform_version                   = "1.4.0"
  propagate_tags                     = "SERVICE"
  region                             = var.aws_region
  task_definition                    = aws_ecs_task_definition.application.arn

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  load_balancer {
    container_name   = local.container_name
    container_port   = var.application_port
    target_group_arn = var.target_group_arn
  }

  network_configuration {
    assign_public_ip = var.assign_public_ip
    security_groups  = [var.security_group_id]
    subnets          = var.subnet_ids
  }

  tags = var.tags
}
