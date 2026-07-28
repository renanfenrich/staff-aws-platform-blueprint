mock_provider "aws" {
  mock_resource "aws_ecr_repository" {
    override_during = plan

    defaults = {
      arn            = "arn:aws:ecr:us-east-1:111122223333:repository/staff-aws-platform-blueprint-sandbox"
      repository_url = "111122223333.dkr.ecr.us-east-1.amazonaws.com/staff-aws-platform-blueprint-sandbox"
    }
  }

  mock_resource "aws_iam_openid_connect_provider" {
    override_during = plan

    defaults = {
      arn = "arn:aws:iam::111122223333:oidc-provider/token.actions.githubusercontent.com"
    }
  }

  mock_resource "aws_iam_role" {
    override_during = plan

    defaults = {
      arn = "arn:aws:iam::111122223333:role/staff-aws-platform-blueprint-sandbox-state"
      id  = "staff-aws-platform-blueprint-sandbox-state"
    }
  }

  mock_resource "aws_s3_bucket" {
    override_during = plan

    defaults = {
      arn    = "arn:aws:s3:::staff-blueprint-state-fixture"
      bucket = "staff-blueprint-state-fixture"
      id     = "staff-blueprint-state-fixture"
    }
  }
}

variables {
  cost_center = "portfolio"
  owner       = "terraform-test"
}

run "disabled_bootstrap_has_no_resources" {
  command = plan

  assert {
    condition = (
      length(module.state) == 0 &&
      length(module.github_oidc) == 0 &&
      length(module.ecr) == 0 &&
      length(module.ecr_publisher) == 0
    )
    error_message = "Disabled bootstrap must not instantiate any AWS resource module."
  }

  assert {
    condition = (
      output.state_bucket_arn == null &&
      output.state_bucket_name == null &&
      output.github_oidc_provider_arn == null &&
      output.github_oidc_subject == null &&
      output.sandbox_state_role_arn == null &&
      output.ecr_repository_arn == null &&
      output.ecr_repository_name == null &&
      output.ecr_repository_url == null &&
      output.image_publisher_role_arn == null
    )
    error_message = "Disabled bootstrap outputs must remain null."
  }
}

run "enabled_bootstrap_is_protected_and_least_privileged" {
  command = plan

  variables {
    bootstrap_enabled = true
    state_bucket_name = "staff-blueprint-state-fixture"
  }

  assert {
    condition     = length(module.state) == 1
    error_message = "Enabled bootstrap must create exactly one protected state bucket module."
  }

  assert {
    condition = (
      length(module.ecr) == 1 &&
      length(module.ecr_publisher) == 1 &&
      module.state[0].test_contract.resource_count +
      module.github_oidc[0].test_contract.resource_count +
      module.ecr[0].test_contract.resource_count +
      module.ecr_publisher[0].test_contract.resource_count == 14
    )
    error_message = "Created-provider bootstrap mode must own the registry and publisher in a 14-resource graph."
  }

  assert {
    condition = (
      module.state[0].test_contract.public_access_block.block_public_acls &&
      module.state[0].test_contract.public_access_block.block_public_policy &&
      module.state[0].test_contract.public_access_block.ignore_public_acls &&
      module.state[0].test_contract.public_access_block.restrict_public_buckets
    )
    error_message = "All four S3 public-access-block settings must be enabled."
  }

  assert {
    condition = (
      module.ecr[0].test_contract.image_tag_mutability == "IMMUTABLE" &&
      module.ecr[0].test_contract.scan_on_push &&
      module.ecr[0].test_contract.encryption_type == "AES256" &&
      !module.ecr[0].test_contract.force_delete &&
      module.ecr[0].test_contract.prevent_destroy
    )
    error_message = "ECR must use immutable tags, scan on push, SSE-S3, no force deletion, and prevent destroy."
  }

  assert {
    condition = (
      length(jsondecode(module.ecr[0].test_contract.lifecycle_policy).rules) == 1 &&
      jsondecode(module.ecr[0].test_contract.lifecycle_policy).rules[0].selection.tagStatus == "tagged" &&
      jsondecode(module.ecr[0].test_contract.lifecycle_policy).rules[0].selection.tagPrefixList == ["git-"] &&
      jsondecode(module.ecr[0].test_contract.lifecycle_policy).rules[0].selection.countType == "imageCountMoreThan" &&
      jsondecode(module.ecr[0].test_contract.lifecycle_policy).rules[0].selection.countNumber == 30 &&
      !strcontains(module.ecr[0].test_contract.lifecycle_policy, "untagged")
    )
    error_message = "ECR lifecycle must retain 30 git-tagged subjects without generic untagged cleanup."
  }

  assert {
    condition     = module.state[0].test_contract.ownership == "BucketOwnerEnforced"
    error_message = "State bucket ownership must be enforced."
  }

  assert {
    condition = (
      module.ecr_publisher[0].test_contract.role_name == "staff-aws-platform-blueprint-sandbox-image-publisher" &&
      module.ecr_publisher[0].test_contract.maximum_session_duration == 3600 &&
      module.ecr_publisher[0].test_contract.audience == "sts.amazonaws.com" &&
      keys(jsondecode(module.ecr_publisher[0].test_contract.trust_policy).Statement[0].Condition) == ["StringEquals"] &&
      jsondecode(module.ecr_publisher[0].test_contract.trust_policy).Statement[0].Principal.Federated == output.github_oidc_provider_arn &&
      jsondecode(module.ecr_publisher[0].test_contract.trust_policy).Statement[0].Condition.StringEquals["token.actions.githubusercontent.com:aud"] == "sts.amazonaws.com" &&
      jsondecode(module.ecr_publisher[0].test_contract.trust_policy).Statement[0].Condition.StringEquals["token.actions.githubusercontent.com:sub"] == "repo:renanfenrich@1413054/staff-aws-platform-blueprint@1314297578:environment:sandbox" &&
      !strcontains(module.ecr_publisher[0].test_contract.trust_policy, "*") &&
      !strcontains(module.ecr_publisher[0].test_contract.trust_policy, "StringLike")
    )
    error_message = "Publisher trust must use the exact provider, audience, and immutable sandbox environment subject."
  }

  assert {
    condition = (
      one([
        for statement in jsondecode(module.ecr_publisher[0].test_contract.publisher_policy).Statement :
        statement
        if statement.Sid == "AuthenticateToPrivateEcr"
      ]).Action == "ecr:GetAuthorizationToken" &&
      one([
        for statement in jsondecode(module.ecr_publisher[0].test_contract.publisher_policy).Statement :
        statement
        if statement.Sid == "AuthenticateToPrivateEcr"
      ]).Resource == "*" &&
      toset(one([
        for statement in jsondecode(module.ecr_publisher[0].test_contract.publisher_policy).Statement :
        statement.Action
        if statement.Sid == "PublishAndVerifyProjectImages"
        ])) == toset([
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
      ]) &&
      one([
        for statement in jsondecode(module.ecr_publisher[0].test_contract.publisher_policy).Statement :
        statement.Resource
        if statement.Sid == "PublishAndVerifyProjectImages"
      ]) == output.ecr_repository_arn
    )
    error_message = "Publisher policy must allow only authentication plus exact-repository publication and verification actions."
  }

  assert {
    condition = alltrue([
      for forbidden in [
        "BatchDeleteImage",
        "DeleteRepository",
        "DeleteRepositoryPolicy",
        "PutLifecyclePolicy",
        "SetRepositoryPolicy",
        "TagResource",
        "UntagResource",
        "s3:",
        "ecs:",
        "ec2:",
        "iam:",
        "logs:",
        "cloudwatch:",
        "secretsmanager:",
        "kms:",
        "sts:AssumeRole\""
      ] : !strcontains(module.ecr_publisher[0].test_contract.publisher_policy, forbidden)
    ])
    error_message = "Publisher policy must contain no deletion, repository management, state, workload, or role-chaining permissions."
  }

  assert {
    condition = (
      output.ecr_repository_name == "staff-aws-platform-blueprint-sandbox" &&
      output.ecr_repository_arn != null &&
      output.ecr_repository_url != null &&
      output.image_publisher_role_arn != null
    )
    error_message = "Enabled bootstrap must expose only the expected non-sensitive ECR and publisher operational values."
  }

  assert {
    condition     = module.state[0].test_contract.versioning_status == "Enabled"
    error_message = "State bucket versioning must be enabled."
  }

  assert {
    condition     = module.state[0].test_contract.encryption_algorithm == "AES256"
    error_message = "State bucket default encryption must use cost-conscious SSE-S3."
  }

  assert {
    condition = (
      one([
        for statement in jsondecode(module.state[0].test_contract.tls_only_policy).Statement :
        statement
        if statement.Sid == "DenyInsecureTransport"
      ]).Effect == "Deny" &&
      one([
        for statement in jsondecode(module.state[0].test_contract.tls_only_policy).Statement :
        statement
        if statement.Sid == "DenyInsecureTransport"
      ]).Condition.Bool["aws:SecureTransport"] == "false"
    )
    error_message = "The bucket policy must deny insecure transport."
  }

  assert {
    condition = (
      module.state[0].test_contract.lifecycle_status == "Enabled" &&
      module.state[0].test_contract.noncurrent_version_retention_days == 90 &&
      module.state[0].test_contract.abort_incomplete_multipart_upload_days == 7 &&
      !module.state[0].test_contract.current_version_expiration_configured
    )
    error_message = "Lifecycle must preserve current state, retain noncurrent versions for 90 days, and bound incomplete uploads."
  }

  assert {
    condition = (
      module.state[0].test_contract.prevent_destroy &&
      !module.state[0].test_contract.website_configuration_is_present
    )
    error_message = "The state bucket must resist accidental destroy and have no website configuration."
  }

  assert {
    condition = (
      module.github_oidc[0].test_contract.github_oidc_url == "https://token.actions.githubusercontent.com" &&
      module.github_oidc[0].test_contract.audience == "sts.amazonaws.com" &&
      module.github_oidc[0].test_contract.maximum_session_duration == 3600 &&
      !module.github_oidc[0].test_contract.thumbprints_configured
    )
    error_message = "The GitHub provider must use the exact URL and audience without a maintained thumbprint."
  }

  assert {
    condition = (
      keys(jsondecode(module.github_oidc[0].test_contract.trust_policy).Statement[0].Condition) == ["StringEquals"] &&
      jsondecode(module.github_oidc[0].test_contract.trust_policy).Statement[0].Condition.StringEquals["token.actions.githubusercontent.com:aud"] == "sts.amazonaws.com" &&
      jsondecode(module.github_oidc[0].test_contract.trust_policy).Statement[0].Condition.StringEquals["token.actions.githubusercontent.com:sub"] == "repo:renanfenrich@1413054/staff-aws-platform-blueprint@1314297578:environment:sandbox" &&
      !strcontains(module.github_oidc[0].test_contract.trust_policy, "*")
    )
    error_message = "Role trust must use exact StringEquals audience and immutable environment subject conditions."
  }

  assert {
    condition = (
      !strcontains(module.github_oidc[0].test_contract.state_policy, "s3:*") &&
      !strcontains(module.github_oidc[0].test_contract.state_policy, "/bootstrap/") &&
      alltrue([
        for prefix in ["iam:", "ecs:", "ec2:", "ecr:", "logs:", "cloudwatch:", "sts:AssumeRole"] :
        !strcontains(module.github_oidc[0].test_contract.state_policy, prefix)
      ])
    )
    error_message = "State role policy must contain only scoped S3 actions and no bootstrap-state access."
  }

  assert {
    condition = (
      toset(one([
        for statement in jsondecode(module.github_oidc[0].test_contract.state_policy).Statement :
        statement.Action
        if statement.Sid == "ReadWriteSandboxState"
      ])) == toset(["s3:GetObject", "s3:PutObject"]) &&
      one([
        for statement in jsondecode(module.github_oidc[0].test_contract.state_policy).Statement :
        statement.Resource
        if statement.Sid == "ReadWriteSandboxState"
      ]) == "arn:aws:s3:::staff-blueprint-state-fixture/staff-aws-platform-blueprint/sandbox/terraform.tfstate"
    )
    error_message = "State object must allow only GetObject and PutObject on the exact sandbox key."
  }

  assert {
    condition = (
      toset(one([
        for statement in jsondecode(module.github_oidc[0].test_contract.state_policy).Statement :
        statement.Action
        if statement.Sid == "ManageSandboxStateLock"
      ])) == toset(["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]) &&
      one([
        for statement in jsondecode(module.github_oidc[0].test_contract.state_policy).Statement :
        statement.Resource
        if statement.Sid == "ManageSandboxStateLock"
      ]) == "arn:aws:s3:::staff-blueprint-state-fixture/staff-aws-platform-blueprint/sandbox/terraform.tfstate.tflock"
    )
    error_message = "Lock object must allow GetObject, PutObject, and DeleteObject on the exact lock key."
  }
}

run "existing_provider_is_referenced_not_created" {
  command = plan

  variables {
    bootstrap_enabled                 = true
    state_bucket_name                 = "staff-blueprint-state-fixture"
    existing_github_oidc_provider_arn = "arn:aws:iam::111122223333:oidc-provider/token.actions.githubusercontent.com"
  }

  assert {
    condition = (
      module.github_oidc[0].test_contract.created_provider_count == 0 &&
      output.github_oidc_provider_arn == "arn:aws:iam::111122223333:oidc-provider/token.actions.githubusercontent.com" &&
      module.state[0].test_contract.resource_count +
      module.github_oidc[0].test_contract.resource_count +
      module.ecr[0].test_contract.resource_count +
      module.ecr_publisher[0].test_contract.resource_count == 13
    )
    error_message = "Existing-provider mode must reference the provider and represent exactly 13 managed resources."
  }
}

run "reject_invalid_bucket_name" {
  command = plan

  variables {
    bootstrap_enabled = true
    state_bucket_name = "Invalid_Bucket"
  }

  expect_failures = [var.state_bucket_name]
}

run "reject_wildcard_subject" {
  command = plan

  variables {
    github_oidc_subject = "repo:renanfenrich/staff-aws-platform-blueprint:*"
  }

  expect_failures = [var.github_oidc_subject]
}

run "reject_non_environment_subject" {
  command = plan

  variables {
    github_oidc_subject = "repo:renanfenrich/staff-aws-platform-blueprint:ref:refs/heads/develop"
  }

  expect_failures = [var.github_oidc_subject]
}

run "reject_malformed_existing_provider_arn" {
  command = plan

  variables {
    existing_github_oidc_provider_arn = "arn:aws:iam::111122223333:role/not-an-oidc-provider"
  }

  expect_failures = [var.existing_github_oidc_provider_arn]
}
