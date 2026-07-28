locals {
  github_oidc_url = "https://token.actions.githubusercontent.com"
  oidc_audience   = "sts.amazonaws.com"
  lock_key        = "${var.state_key}.tflock"

  provider_arn = coalesce(
    var.existing_provider_arn,
    try(aws_iam_openid_connect_provider.github[0].arn, null)
  )

  trust_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "GitHubSandboxEnvironment"
      Effect = "Allow"
      Principal = {
        Federated = local.provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = local.oidc_audience
          "token.actions.githubusercontent.com:sub" = var.github_subject
        }
      }
    }]
  })

  state_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ListSandboxStatePrefix"
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = var.state_bucket_arn
        Condition = {
          StringEquals = {
            "s3:prefix" = [var.state_key, local.lock_key]
          }
        }
      },
      {
        Sid    = "InspectStateBucketControls"
        Effect = "Allow"
        Action = [
          "s3:GetBucketLocation",
          "s3:GetBucketVersioning",
          "s3:GetEncryptionConfiguration",
          "s3:GetBucketPublicAccessBlock"
        ]
        Resource = var.state_bucket_arn
      },
      {
        Sid    = "ReadWriteSandboxState"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "${var.state_bucket_arn}/${var.state_key}"
      },
      {
        Sid    = "ManageSandboxStateLock"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${var.state_bucket_arn}/${local.lock_key}"
      }
    ]
  })
}

resource "aws_iam_openid_connect_provider" "github" {
  count = var.existing_provider_arn == null ? 1 : 0

  url            = local.github_oidc_url
  client_id_list = [local.oidc_audience]
  tags           = var.tags
}

resource "aws_iam_role" "state" {
  name                 = var.role_name
  assume_role_policy   = local.trust_policy
  max_session_duration = 3600
  tags                 = var.tags
}

resource "aws_iam_role_policy" "state" {
  name   = "sandbox-state-access"
  role   = aws_iam_role.state.id
  policy = local.state_policy
}
