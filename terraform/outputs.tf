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
