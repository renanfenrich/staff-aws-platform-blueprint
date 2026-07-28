variable "application_port" {
  description = "Port exposed by the application container and ALB target group."
  type        = number
  default     = 8080
  nullable    = false

  validation {
    condition     = var.application_port >= 1024 && var.application_port <= 65535
    error_message = "application_port must be between 1024 and 65535."
  }
}

variable "availability_zones" {
  description = "Two distinct Availability Zones used by the sandbox public subnets."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
  nullable    = false

  validation {
    condition = (
      length(var.availability_zones) == 2 &&
      length(distinct(var.availability_zones)) == 2 &&
      alltrue([
        for zone in var.availability_zones :
        length(trimspace(zone)) > 0 && startswith(zone, var.aws_region)
      ])
    )
    error_message = "availability_zones must contain exactly two distinct zones in aws_region."
  }
}

variable "aws_region" {
  description = "AWS region for the disposable sandbox."
  type        = string
  default     = "us-east-1"
  nullable    = false

  validation {
    condition     = can(regex("^[a-z]{2}(-gov)?-[a-z]+-[0-9]+$", var.aws_region))
    error_message = "aws_region must be a valid AWS region name."
  }
}

variable "container_image" {
  description = "Immutable image in the externally managed ECR repository. Required as a sha256 digest when enabled."
  type        = string
  default     = ""
  nullable    = false

  validation {
    condition = (
      !var.deployment_enabled ||
      (
        can(regex(
          "^[0-9]{12}\\.dkr\\.ecr\\.[a-z]{2}(-gov)?-[a-z]+-[0-9]+\\.amazonaws\\.com(\\.cn)?/[a-z0-9]+([._/-][a-z0-9]+)*@sha256:[0-9a-f]{64}$",
          var.container_image
        )) &&
        try(split("@", var.container_image)[0] == var.ecr_repository_url, false)
      )
    )
    error_message = "container_image must be the configured private ECR repository URL plus an exact sha256 digest."
  }

  validation {
    condition     = !can(regex("(?i)(^|:)latest($|@)", var.container_image))
    error_message = "container_image must not use the mutable latest tag."
  }
}

variable "cost_center" {
  description = "Cost allocation identifier applied to every taggable resource."
  type        = string
  nullable    = false

  validation {
    condition     = length(trimspace(var.cost_center)) > 0
    error_message = "cost_center must not be empty."
  }
}

variable "deployment_enabled" {
  description = "Explicit cost gate. No AWS resources exist in the graph unless true."
  type        = bool
  default     = false
  nullable    = false
}

variable "desired_task_count" {
  description = "Number of Fargate tasks in the sandbox service."
  type        = number
  default     = 1
  nullable    = false

  validation {
    condition     = var.desired_task_count >= 1 && var.desired_task_count <= 4 && floor(var.desired_task_count) == var.desired_task_count
    error_message = "desired_task_count must be an integer between 1 and 4."
  }
}

variable "ecr_repository_arn" {
  description = "Existing private ECR repository ARN owned by the bootstrap foundation."
  type        = string
  default     = ""
  nullable    = false

  validation {
    condition = (
      !var.deployment_enabled ||
      can(regex(
        "^arn:(aws|aws-us-gov|aws-cn):ecr:[a-z]{2}(-gov)?-[a-z]+-[0-9]+:[0-9]{12}:repository/[a-z0-9]+([._/-][a-z0-9]+)*$",
        var.ecr_repository_arn
      ))
    )
    error_message = "ecr_repository_arn must be a valid private ECR repository ARN when deployment is enabled."
  }
}

variable "ecr_repository_url" {
  description = "Existing private ECR repository URL owned by the bootstrap foundation."
  type        = string
  default     = ""
  nullable    = false

  validation {
    condition = (
      !var.deployment_enabled ||
      can(regex(
        "^[0-9]{12}\\.dkr\\.ecr\\.[a-z]{2}(-gov)?-[a-z]+-[0-9]+\\.amazonaws\\.com(\\.cn)?/[a-z0-9]+([._/-][a-z0-9]+)*$",
        var.ecr_repository_url
      ))
    )
    error_message = "ecr_repository_url must be a valid private ECR repository URL when deployment is enabled."
  }
}

variable "environment" {
  description = "Deployment environment used for naming and policy boundaries."
  type        = string
  default     = "sandbox"
  nullable    = false

  validation {
    condition     = contains(["sandbox", "staging", "production"], var.environment)
    error_message = "environment must be sandbox, staging, or production."
  }
}

variable "health_check_grace_period_seconds" {
  description = "Time ECS ignores load balancer health failures after a task starts."
  type        = number
  default     = 30
  nullable    = false

  validation {
    condition     = var.health_check_grace_period_seconds >= 0 && var.health_check_grace_period_seconds <= 300
    error_message = "health_check_grace_period_seconds must be between 0 and 300."
  }
}

variable "health_check_path" {
  description = "ALB readiness health-check path."
  type        = string
  default     = "/ready"
  nullable    = false

  validation {
    condition     = startswith(var.health_check_path, "/") && length(var.health_check_path) <= 128
    error_message = "health_check_path must be a non-empty absolute path up to 128 characters."
  }
}

variable "log_retention_days" {
  description = "CloudWatch application log retention for the disposable sandbox."
  type        = number
  default     = 7
  nullable    = false

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90], var.log_retention_days)
    error_message = "log_retention_days must be one of 1, 3, 5, 7, 14, 30, 60, or 90."
  }
}

variable "network_profile" {
  description = "Network placement profile. Only the disposable public-IP sandbox is implemented."
  type        = string
  default     = "sandbox-public"
  nullable    = false

  validation {
    condition     = var.network_profile == "sandbox-public"
    error_message = "network_profile must be sandbox-public in this slice."
  }

  validation {
    condition     = var.environment != "production" || var.network_profile != "sandbox-public"
    error_message = "production must not use the sandbox-public network profile."
  }
}

variable "owner" {
  description = "Accountable owner applied to every taggable resource."
  type        = string
  nullable    = false

  validation {
    condition     = length(trimspace(var.owner)) > 0
    error_message = "owner must not be empty."
  }
}

variable "project_name" {
  description = "Stable project identifier used for names and tags."
  type        = string
  default     = "staff-aws-platform-blueprint"
  nullable    = false

  validation {
    condition = (
      length(var.project_name) >= 3 &&
      length(var.project_name) <= 40 &&
      can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.project_name))
    )
    error_message = "project_name must be 3-40 lowercase alphanumeric or hyphen characters."
  }
}

variable "public_subnet_cidrs" {
  description = "Two distinct, non-overlapping /24 public subnet CIDRs inside the VPC CIDR."
  type        = list(string)
  default     = ["10.42.0.0/24", "10.42.1.0/24"]
  nullable    = false

  validation {
    condition = (
      length(var.public_subnet_cidrs) == 2 &&
      length(distinct(var.public_subnet_cidrs)) == 2 &&
      alltrue([
        for cidr in var.public_subnet_cidrs :
        can(cidrnetmask(cidr)) &&
        endswith(cidr, "/24") &&
        try(cidr == "${cidrhost(cidr, 0)}/24", false)
      ])
    )
    error_message = "public_subnet_cidrs must contain exactly two distinct canonical /24 IPv4 CIDRs."
  }

  validation {
    condition = try(alltrue([
      for cidr in var.public_subnet_cidrs :
      contains([for index in range(256) : cidrsubnet(var.vpc_cidr, 8, index)], cidr)
    ]), false)
    error_message = "Every public subnet must be contained in vpc_cidr."
  }
}

variable "task_cpu" {
  description = "Fargate task CPU units."
  type        = number
  default     = 256
  nullable    = false

  validation {
    condition     = contains([256, 512, 1024, 2048, 4096], var.task_cpu)
    error_message = "task_cpu must be a supported Fargate CPU value."
  }
}

variable "task_memory" {
  description = "Fargate task memory in MiB."
  type        = number
  default     = 512
  nullable    = false

  validation {
    condition = contains(lookup({
      256  = [512, 1024, 2048]
      512  = [1024, 2048, 3072, 4096]
      1024 = [2048, 3072, 4096, 5120, 6144, 7168, 8192]
      2048 = [4096, 5120, 6144, 7168, 8192, 9216, 10240, 11264, 12288, 13312, 14336, 15360, 16384]
      4096 = [8192, 9216, 10240, 11264, 12288, 13312, 14336, 15360, 16384, 17408, 18432, 19456, 20480, 21504, 22528, 23552, 24576, 25600, 26624, 27648, 28672, 29696, 30720]
    }, var.task_cpu, []), var.task_memory)
    error_message = "task_memory must be supported for the selected task_cpu."
  }
}

variable "vpc_cidr" {
  description = "IPv4 CIDR for the disposable sandbox VPC."
  type        = string
  default     = "10.42.0.0/16"
  nullable    = false

  validation {
    condition = (
      can(cidrnetmask(var.vpc_cidr)) &&
      can(regex("^(10\\.|172\\.(1[6-9]|2[0-9]|3[01])\\.|192\\.168\\.)", var.vpc_cidr)) &&
      endswith(var.vpc_cidr, "/16") &&
      try(var.vpc_cidr == "${cidrhost(var.vpc_cidr, 0)}/16", false)
    )
    error_message = "vpc_cidr must be a canonical private RFC 1918 /16 IPv4 CIDR."
  }
}
