# Terraform Network Foundation

This phase creates a two-AZ network with three subnet tiers:

- public subnets for the future Application Load Balancer and zonal NAT gateways;
- private application subnets with NAT egress and no automatic public addressing;
- isolated database subnets with no Internet default route.

The VPC default security group is managed with no ingress or egress rules. Workloads use dedicated tier security groups with explicit ALB-to-application and application-to-database references; application instances have no SSH ingress.

The default `per_az` NAT mode favors resiliency by routing each application subnet through a NAT gateway in the same Availability Zone. `single` mode is available for short lab sessions where reduced cost is explicitly preferred over zonal egress resilience.

## Validate

```bash
terraform init
terraform fmt -check
terraform validate
terraform plan
```

Copy `terraform.tfvars.example` to an ignored `terraform.tfvars` only when values need to be overridden. Do not place credentials or secret values in Terraform variable files.

Running `terraform plan` or `terraform apply` requires valid temporary AWS credentials. Review the plan and expected NAT gateway costs before applying.
