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

The audit tier captures all VPC accepted and rejected flows in an enriched one-minute format. A multi-Region CloudTrail records read and write management events plus global-service events, validates log-file integrity, writes to a KMS-encrypted and versioned S3 bucket, and also streams events to CloudWatch Logs. The audit bucket blocks public access, denies non-TLS requests, records server access logs in a separate bucket, transitions records to Glacier Instant Retrieval after 90 days, and defaults to one-year retention. Metric filters alert on security-group changes and CloudTrail configuration changes.

The application edge uses a regional AWS WAF web ACL associated with the ALB. AWS-managed SQL injection, core, and known-bad-input rule groups block matching requests before a per-IP one-minute rate rule. Detailed logs retain only blocked requests, redact query strings and authorization headers, disable request sampling, and use the observability KMS key. WAF allowed/blocked metrics, recent blocks, and a blocked-request alarm appear in the operations dashboard.

The security-detection tier enables GuardDuty with S3 data-event, EBS malware, and EC2 runtime-monitoring features. AWS Config continuously records supported resources into the encrypted audit bucket and evaluates seven managed controls covering SSH exposure, EBS/RDS encryption, RDS public access, CloudTrail, Flow Logs, and ALB/WAF association. Security Hub V2 and Security Hub CSPM are enabled, with FSBP selected explicitly. Filtered GuardDuty, Config, and CSPM events route through EventBridge to a dedicated KMS-encrypted security topic; failed target deliveries use an encrypted SQS DLQ and CloudWatch alarms.

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

Also review Multi-AZ RDS, backup storage, KMS, Secrets Manager, CloudWatch Logs, CloudTrail, S3, archival storage, AWS WAF, GuardDuty protection plans, AWS Config evaluations, Security Hub CSPM controls, SNS, and SQS costs. These security services continue generating charges while enabled even when the application is idle.
