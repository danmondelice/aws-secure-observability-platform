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
