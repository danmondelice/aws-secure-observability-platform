variable "aws_region" {
  description = "AWS Region in which to create the lab resources."
  type        = string
  default     = "us-east-2"

  validation {
    condition     = can(regex("^[a-z]{2}(-gov)?-[a-z]+-[0-9]$", var.aws_region))
    error_message = "aws_region must be a valid AWS Region identifier."
  }
}

variable "project_name" {
  description = "Short project identifier used in names and tags."
  type        = string
  default     = "aws-secure-observability-platform"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,47}$", var.project_name))
    error_message = "project_name must be 3-48 lowercase letters, digits, or hyphens and start with a letter."
  }
}

variable "environment" {
  description = "Deployment environment label."
  type        = string
  default     = "lab"

  validation {
    condition     = contains(["lab", "dev", "stage", "prod"], var.environment)
    error_message = "environment must be one of: lab, dev, stage, prod."
  }
}

variable "owner" {
  description = "Owner tag used for accountability and cost allocation."
  type        = string
  default     = "danmondelice"

  validation {
    condition     = length(trimspace(var.owner)) > 0
    error_message = "owner must not be empty."
  }
}

variable "vpc_cidr" {
  description = "IPv4 CIDR for the VPC. A /16 provides room for the planned /24 subnets."
  type        = string
  default     = "10.20.0.0/16"

  validation {
    condition     = can(cidrsubnet(var.vpc_cidr, 8, 0)) && tonumber(split("/", var.vpc_cidr)[1]) <= 20
    error_message = "vpc_cidr must be valid IPv4 CIDR with enough space for /24 subnets."
  }
}

variable "nat_gateway_mode" {
  description = "NAT topology: per_az is resilient; single lowers lab cost but creates an AZ dependency."
  type        = string
  default     = "per_az"

  validation {
    condition     = contains(["per_az", "single"], var.nat_gateway_mode)
    error_message = "nat_gateway_mode must be either per_az or single."
  }
}

variable "app_port" {
  description = "TCP port exposed by the application service to the ALB."
  type        = number
  default     = 8000

  validation {
    condition     = var.app_port >= 1024 && var.app_port <= 65535
    error_message = "app_port must be between 1024 and 65535."
  }
}

variable "database_port" {
  description = "Database listener port permitted from the application security group."
  type        = number
  default     = 3306

  validation {
    condition     = var.database_port >= 1 && var.database_port <= 65535
    error_message = "database_port must be between 1 and 65535."
  }
}

variable "additional_tags" {
  description = "Additional non-sensitive tags to apply to all supported resources."
  type        = map(string)
  default     = {}
}

variable "instance_type" {
  description = "EC2 instance type for the application Auto Scaling group."
  type        = string
  default     = "t4g.micro"

  validation {
    condition     = can(regex("^[a-z][a-z0-9]*[0-9][a-z]*\\.[a-z0-9]+$", var.instance_type))
    error_message = "instance_type must be a valid EC2 instance type identifier."
  }
}

variable "asg_min_size" {
  description = "Minimum application instance count."
  type        = number
  default     = 2
}

variable "asg_desired_capacity" {
  description = "Normal application instance count."
  type        = number
  default     = 2
}

variable "asg_max_size" {
  description = "Maximum application instance count."
  type        = number
  default     = 4
}

variable "application_git_ref" {
  description = "Immutable Git commit used to bootstrap the application."
  type        = string
  default     = "c19a8f0ddf960d3d32513e456ddd5e547ffe8597"

  validation {
    condition     = can(regex("^[0-9a-f]{40}$", var.application_git_ref))
    error_message = "application_git_ref must be a full 40-character Git commit SHA."
  }
}

variable "certificate_arn" {
  description = "Optional ACM certificate ARN. When null, the lab exposes HTTP only; when set, HTTP redirects to HTTPS."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.certificate_arn == null || can(regex("^arn:aws(-[a-z]+)?:acm:[a-z0-9-]+:[0-9]{12}:certificate/[0-9a-f-]+$", var.certificate_arn))
    error_message = "certificate_arn must be null or a valid ACM certificate ARN."
  }
}

variable "enable_deletion_protection" {
  description = "Protect the ALB from accidental deletion. Disabled by default for a disposable lab."
  type        = bool
  default     = false
}

variable "database_engine_version" {
  description = "Pinned MySQL engine version verified in the target Region."
  type        = string
  default     = "8.4.9"

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.database_engine_version))
    error_message = "database_engine_version must be a full semantic engine version such as 8.4.9."
  }
}

variable "database_instance_class" {
  description = "RDS instance class for the lab database."
  type        = string
  default     = "db.t4g.micro"

  validation {
    condition     = startswith(var.database_instance_class, "db.")
    error_message = "database_instance_class must start with db."
  }
}

variable "database_name" {
  description = "Initial application database name."
  type        = string
  default     = "secureapp"

  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9_]{0,63}$", var.database_name))
    error_message = "database_name must start with a letter and contain at most 64 letters, digits, or underscores."
  }
}

variable "database_master_username" {
  description = "RDS master username. The password is generated and managed by RDS in Secrets Manager."
  type        = string
  default     = "platformadmin"

  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9_]{0,15}$", var.database_master_username))
    error_message = "database_master_username must start with a letter and contain at most 16 letters, digits, or underscores."
  }
}

variable "database_multi_az" {
  description = "Deploy a synchronous Multi-AZ standby. Keep true for availability testing."
  type        = bool
  default     = true
}

variable "enable_database_query_logging" {
  description = "Export the MySQL general query log. Useful for the lab but increases CloudWatch log volume."
  type        = bool
  default     = true
}

variable "database_deletion_protection" {
  description = "Protect the RDS instance from deletion. Must be true for environment=prod."
  type        = bool
  default     = false
}

variable "database_skip_final_snapshot" {
  description = "Skip a final snapshot during deletion. Suitable only for a disposable lab."
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention for application, host, and database logs."
  type        = number
  default     = 30

  validation {
    condition = contains([
      1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365,
      400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653,
    ], var.log_retention_days)
    error_message = "log_retention_days must be a CloudWatch Logs-supported retention value."
  }
}

variable "alert_email" {
  description = "Optional email endpoint for operational SNS alerts. Subscription requires confirmation."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.alert_email == null || can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.alert_email))
    error_message = "alert_email must be null or a syntactically valid email address."
  }
}
