output "vpc_id" {
  description = "ID of the application VPC."
  value       = aws_vpc.main.id
}

output "availability_zones" {
  description = "Availability Zones selected for this deployment."
  value       = local.availability_zones
}

output "public_subnet_ids" {
  description = "Public subnet IDs keyed by Availability Zone."
  value       = { for az, subnet in aws_subnet.public : az => subnet.id }
}

output "app_subnet_ids" {
  description = "Private application subnet IDs keyed by Availability Zone."
  value       = { for az, subnet in aws_subnet.app : az => subnet.id }
}

output "db_subnet_ids" {
  description = "Isolated database subnet IDs keyed by Availability Zone."
  value       = { for az, subnet in aws_subnet.db : az => subnet.id }
}

output "security_group_ids" {
  description = "Security group IDs for the ALB, application, and database tiers."
  value = {
    alb = aws_security_group.alb.id
    app = aws_security_group.app.id
    db  = aws_security_group.db.id
  }
}

output "nat_gateway_mode" {
  description = "Selected NAT gateway topology."
  value       = var.nat_gateway_mode
}

output "alb_dns_name" {
  description = "Public DNS name of the Application Load Balancer."
  value       = aws_lb.app.dns_name
}

output "alb_url" {
  description = "Application URL using HTTPS when a certificate is configured."
  value       = "${var.certificate_arn == null ? "http" : "https"}://${aws_lb.app.dns_name}"
}

output "autoscaling_group_name" {
  description = "Application Auto Scaling group name."
  value       = aws_autoscaling_group.app.name
}

output "launch_template_id" {
  description = "Application EC2 launch template ID."
  value       = aws_launch_template.app.id
}

output "database_endpoint" {
  description = "Private RDS endpoint without credentials."
  value       = aws_db_instance.app.endpoint
}

output "database_secret_arn" {
  description = "ARN of the RDS-managed master-user secret. The secret value is never output."
  value       = aws_db_instance.app.master_user_secret[0].secret_arn
  sensitive   = true
}

output "database_kms_key_arn" {
  description = "KMS key used for RDS storage and its managed secret."
  value       = aws_kms_key.database.arn
}

output "operations_dashboard_name" {
  description = "CloudWatch operations dashboard name."
  value       = aws_cloudwatch_dashboard.operations.dashboard_name
}

output "operations_topic_arn" {
  description = "Encrypted SNS topic for operational alarm transitions."
  value       = aws_sns_topic.operations.arn
}

output "cloudtrail_name" {
  description = "Name of the multi-Region management-event trail."
  value       = aws_cloudtrail.management.name
}

output "audit_bucket_name" {
  description = "S3 bucket containing encrypted CloudTrail log and digest files."
  value       = aws_s3_bucket.audit.id
}

output "vpc_flow_log_group_name" {
  description = "CloudWatch Logs group receiving VPC Flow Logs."
  value       = aws_cloudwatch_log_group.vpc_flow.name
}

output "cloudtrail_log_group_name" {
  description = "CloudWatch Logs group receiving CloudTrail management events."
  value       = aws_cloudwatch_log_group.cloudtrail.name
}
