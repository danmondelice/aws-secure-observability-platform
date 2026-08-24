# Terraform Infrastructure

This phase creates a two-AZ network with three subnet tiers:

- public subnets for the future Application Load Balancer and zonal NAT gateways;
- private application subnets with NAT egress and no automatic public addressing;
- isolated database subnets with no Internet default route.

The VPC default security group is managed with no ingress or egress rules. Workloads use dedicated tier security groups with explicit ALB-to-application and application-to-database references; application instances have no SSH ingress.

The default `per_az` NAT mode favors resiliency by routing each application subnet through a NAT gateway in the same Availability Zone. `single` mode is available for short lab sessions where reduced cost is explicitly preferred over zonal egress resilience.

The compute tier adds an Application Load Balancer and two-instance EC2 Auto Scaling group. Instances use an immutable Amazon Linux 2023 Arm64 AMI reference, required IMDSv2, encrypted EBS, standard burst credits, detailed monitoring, and Session Manager instead of SSH. The ASG uses ELB health replacement, target tracking, and rolling instance refresh.

The database tier uses private isolated subnets, encrypted MySQL 8.4 Multi-AZ RDS, seven-day backups, storage autoscaling, IAM database authentication support, and error/general/slow-query log exports. RDS generates its master password directly in Secrets Manager under a rotating KMS key, so Terraform never receives a plaintext password. See the [database credential ADR](../docs/architecture-decisions/0001-database-credential-lifecycle.md) for the required application-user hardening step.

The observability tier installs the CloudWatch Agent on EC2, collects structured application/bootstrap/system logs and aggregate CPU/memory/disk metrics, encrypts log groups with a project KMS key, and displays ALB, ASG, host, RDS, alarm, and error-log views on an eight-hour operations dashboard. M-of-N alarms use explicit missing-data behavior and publish ALARM/OK transitions to a separately encrypted SNS topic.

With no `certificate_arn`, the disposable lab listener serves HTTP. Supplying a same-Region ACM certificate enables HTTPS and changes HTTP to a permanent redirect. Do not describe the deployment as TLS-protected until that certificate path has been applied and tested.

## Validate

```bash
terraform init
terraform fmt -check
terraform validate
terraform plan
```

Copy `terraform.tfvars.example` to an ignored `terraform.tfvars` only when values need to be overridden. Do not place credentials or secret values in Terraform variable files.

Running `terraform plan` or `terraform apply` requires valid temporary AWS credentials. Review the plan and expected NAT gateway costs before applying.

Also review Multi-AZ RDS, backup storage, KMS, Secrets Manager, and CloudWatch Logs costs. General-query logging is intentionally enabled for this evidence-driven lab and should be disabled when its diagnostic value does not justify the volume.
