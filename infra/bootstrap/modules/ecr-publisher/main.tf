locals {
  oidc_audience = "sts.amazonaws.com"

  trust_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "GitHubSandboxImagePublication"
      Effect = "Allow"
      Principal = {
        Federated = var.github_oidc_provider_arn
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

  publisher_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AuthenticateToPrivateEcr"
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Sid    = "PublishAndVerifyProjectImages"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeImages",
          "ecr:DescribeImageScanFindings",
          "ecr:DescribeRepositories",
          "ecr:GetDownloadUrlForLayer",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart"
        ]
        Resource = var.ecr_repository_arn
      }
    ]
  })
}

resource "aws_iam_role" "publisher" {
  name                 = var.role_name
  assume_role_policy   = local.trust_policy
  max_session_duration = 3600
  tags                 = var.tags
}

resource "aws_iam_role_policy" "publisher" {
  name   = "sandbox-image-publication"
  role   = aws_iam_role.publisher.id
  policy = local.publisher_policy
}
