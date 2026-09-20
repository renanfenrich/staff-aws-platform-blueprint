resource "aws_ecs_task_definition" "migration" {
  container_definitions = jsonencode([{
    name                   = "migration"
    image                  = var.container_image
    command                = ["node", "dist/db/migrate.js"]
    essential              = true
    readonlyRootFilesystem = true
    privileged             = false
    user                   = "1000"
    environment = [
      { name = "NODE_ENV", value = "production" },
      { name = "DATABASE_HOST", value = var.database_host },
      { name = "DATABASE_PORT", value = tostring(var.database_port) },
      { name = "DATABASE_NAME", value = var.database_name },
      { name = "DATABASE_USER", value = var.database_user },
      { name = "DATABASE_SECRET_ARN", value = var.database_secret_arn },
      { name = "AWS_REGION", value = var.aws_region },
      { name = "DATABASE_SSL_CA_PATH", value = var.database_ssl_ca_path },
    ]
    linuxParameters  = { capabilities = { add = [], drop = ["ALL"] } }
    logConfiguration = { logDriver = "awslogs", options = { awslogs-group = var.log_group_name, awslogs-region = var.aws_region, awslogs-stream-prefix = "migration" } }
  }])
  cpu                      = "256"
  execution_role_arn       = var.execution_role_arn
  family                   = "${var.name}-migration"
  memory                   = "512"
  network_mode             = "awsvpc"
  region                   = var.aws_region
  requires_compatibilities = ["FARGATE"]
  task_role_arn            = var.backend_role_arn
  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }
  tags = var.tags
}
