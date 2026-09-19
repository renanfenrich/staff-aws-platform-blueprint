resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-database"
  region     = var.aws_region
  subnet_ids = var.database_subnet_ids
  tags       = var.tags
}

resource "aws_db_parameter_group" "postgres" {
  family = "postgres17"
  name   = "${var.name}-postgres17"
  region = var.aws_region
  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }
  tags = var.tags
}

resource "aws_db_instance" "this" {
  allocated_storage            = 20
  auto_minor_version_upgrade   = false
  backup_retention_period      = 1
  db_name                      = "tracker"
  db_subnet_group_name         = aws_db_subnet_group.this.name
  deletion_protection          = false
  engine                       = "postgres"
  engine_version               = "17.11"
  identifier                   = "${var.name}-postgres"
  instance_class               = "db.t4g.micro"
  manage_master_user_password  = true
  username                     = "tracker_admin"
  monitoring_interval          = 0
  multi_az                     = false
  parameter_group_name         = aws_db_parameter_group.postgres.name
  performance_insights_enabled = false
  publicly_accessible          = false
  region                       = var.aws_region
  skip_final_snapshot          = true
  storage_encrypted            = true
  storage_type                 = "gp3"
  vpc_security_group_ids       = [var.database_security_group_id]
  tags                         = var.tags
}
