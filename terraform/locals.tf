locals {
  name_prefix        = "${var.project_name}-${var.environment}"
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 2)

  subnet_configuration = {
    for index, az in local.availability_zones : az => {
      public_cidr = cidrsubnet(var.vpc_cidr, 8, index)
      app_cidr    = cidrsubnet(var.vpc_cidr, 8, index + 10)
      db_cidr     = cidrsubnet(var.vpc_cidr, 8, index + 20)
    }
  }

  nat_gateway_azs = var.nat_gateway_mode == "per_az" ? toset(local.availability_zones) : toset([local.availability_zones[0]])
  primary_az      = local.availability_zones[0]
  vpc_resolver_ip = "${cidrhost(var.vpc_cidr, 2)}/32"

  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = var.owner
      Repository  = "aws-secure-observability-platform"
    },
    var.additional_tags
  )
}
