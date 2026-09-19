output "address" { value = aws_db_instance.this.address }
output "database_name" { value = aws_db_instance.this.db_name }
output "master_secret_arn" { value = aws_db_instance.this.master_user_secret[0].secret_arn }
output "port" { value = aws_db_instance.this.port }
output "username" { value = aws_db_instance.this.username }
output "test_contract" {
  value = {
    database_subnet_ids = aws_db_subnet_group.this.subnet_ids
    engine              = aws_db_instance.this.engine
    engine_version      = aws_db_instance.this.engine_version
    force_ssl           = one([for parameter in aws_db_parameter_group.postgres.parameter : parameter if parameter.name == "rds.force_ssl"])
    managed_secret_arn  = aws_db_instance.this.master_user_secret[0].secret_arn
    publicly_accessible = aws_db_instance.this.publicly_accessible
    resource_count      = 3
    storage_encrypted   = aws_db_instance.this.storage_encrypted
  }
}
