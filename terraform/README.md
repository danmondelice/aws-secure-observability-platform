# Terraform Infrastructure

This phase creates a two-AZ network with three subnet tiers:

- public subnets for the future Application Load Balancer and zonal NAT gateways;
- private application subnets with NAT egress and no automatic public addressing;
- isolated database subnets with no Internet default route.

The VPC default security group is managed with no ingress or egress rules. Workloads use dedicated tier security groups with explicit ALB-to-application and application-to-database references; application instances have no SSH ingress.

The default `per_az` NAT mode favors resiliency by routing each application subnet through a NAT gateway in the same Availability Zone. `single` mode is available for short lab sessions where reduced cost is explicitly preferred over zonal egress resilience.

The compute tier adds an Application Load Balancer and two-instance EC2 Auto Scaling group. Instances use an immutable Amazon Linux 2023 Arm64 AMI reference, required IMDSv2, encrypted EBS, standard burst credits, detailed monitoring, and Session Manager instead of SSH. The ASG uses ELB health replacement, target tracking, and rolling instance refresh.

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
