locals {
  name_prefix          = "${var.project_name}-${var.environment}"
  physical_name_prefix = "asop-${var.environment}"
  availability_zones   = slice(data.aws_availability_zones.available.names, 0, 2)

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

  application_log_group_name = "/aws/ec2/${var.project_name}/${var.environment}/application"
  bootstrap_log_group_name   = "/aws/ec2/${var.project_name}/${var.environment}/bootstrap"
  system_log_group_name      = "/aws/ec2/${var.project_name}/${var.environment}/system"
  flow_log_group_name        = "/aws/vpc/${var.project_name}/${var.environment}/flow-logs"
  cloudtrail_log_group_name  = "/aws/cloudtrail/${var.project_name}/${var.environment}/management"
  waf_log_group_name         = "aws-waf-logs-${local.physical_name_prefix}-web-acl"
  notification_topic_name    = "${local.physical_name_prefix}-operations-alerts"
  security_topic_name        = "${local.physical_name_prefix}-security-alerts"
  security_dlq_name          = "${local.physical_name_prefix}-security-events-dlq"
  cloudtrail_name            = "${local.physical_name_prefix}-management-trail"
  audit_bucket_name          = "${local.physical_name_prefix}-audit-${data.aws_caller_identity.current.account_id}-${var.aws_region}"
  audit_access_bucket_name   = "${local.physical_name_prefix}-audit-access-${data.aws_caller_identity.current.account_id}-${var.aws_region}"

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
