output "bucket_arn" {
  description = "State bucket ARN."
  value       = aws_s3_bucket.state.arn
}

output "bucket_name" {
  description = "State bucket name."
  value       = aws_s3_bucket.state.bucket
}

output "test_contract" {
  description = "Security properties exposed for deterministic Terraform tests."
  value = {
    abort_incomplete_multipart_upload_days = 7
    current_version_expiration_configured  = false
    encryption_algorithm                   = one(one(aws_s3_bucket_server_side_encryption_configuration.state.rule).apply_server_side_encryption_by_default).sse_algorithm
    lifecycle_status                       = "Enabled"
    noncurrent_version_retention_days      = var.noncurrent_version_retention_days
    ownership                              = one(aws_s3_bucket_ownership_controls.state.rule).object_ownership
    prevent_destroy                        = true
    public_access_block                    = aws_s3_bucket_public_access_block.state
    resource_count                         = 7
    tls_only_policy                        = local.tls_only_policy
    versioning_status                      = one(aws_s3_bucket_versioning.state.versioning_configuration).status
    website_configuration_is_present       = false
  }
}
