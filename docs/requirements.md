# Production Requirements

## Availability

- Run the application in at least two Availability Zones.
- Maintain at least two healthy application instances during normal operation.
- Place an Application Load Balancer in public subnets and application instances in private subnets.
- Use Auto Scaling health replacement and ALB health checks.
- Measure instance replacement and application recovery time.

## Network security

- Assign no public IPv4 address to application instances.
- Provide no inbound SSH rule and install no operational dependency on SSH.
- Use Systems Manager Session Manager for approved administration.
- Permit application ingress only from the ALB security group.
- Make RDS non-public and permit its database port only from the application security group.
- Require encrypted connections to the database where supported by the selected engine.

## Identity and secrets

- Use temporary AWS credentials for operators.
- Give EC2 a dedicated least-privilege instance role.
- Scope secret retrieval to the single application secret.
- Require IMDSv2 on every launch-template version.
- Store no secret values in Git, Terraform configuration/state inputs, user data, or application source.
- Encrypt Secrets Manager, RDS, EBS, log archives, and notification topics using an explicit key strategy.

## Preventive and detective security

- Associate WAF with the ALB using managed common, known-bad-input, and SQL injection protections plus a rate-based rule.
- Log WAF requests to an approved encrypted destination with bounded retention.
- Record management events with a multi-Region CloudTrail trail, log validation, and an encrypted S3 destination.
- Record relevant VPC traffic metadata with Flow Logs.
- Enable GuardDuty and use only AWS-supported sample findings for validation.
- Record resource configuration and evaluate selected managed AWS Config rules.
- Aggregate relevant findings in Security Hub where account prerequisites and cost boundaries permit.
- Route actionable security and operational events to distinct notification paths.

## Observability

- Collect application and system logs with defined retention.
- Publish memory and disk metrics with the CloudWatch Agent.
- Dashboard ALB request volume, latency, target 5xx, and target health.
- Dashboard EC2 CPU, memory, disk, status checks, and network activity.
- Dashboard RDS CPU, connections, storage, latency, and freeable memory.
- Alarm on loss of healthy targets, target 5xx, instance status failure, sustained CPU pressure, and selected RDS conditions.
- Configure alarms deliberately for missing-data behavior and recovery notifications.

## Auditability and reproducibility

- Manage long-lived infrastructure with Terraform.
- Pin Terraform and provider version constraints and commit the dependency lock file.
- Format, validate, and review a saved plan before deployment.
- Tag resources consistently for project, environment, owner, and cost tracking.
- Keep intentional incident injection outside normal Terraform reconciliation and document every temporary mutation and rollback.

## Cost and operational safety

- Default to a single disposable lab environment.
- Declare expensive services and their expected cost drivers before deployment, especially NAT gateways, RDS, Config, WAF, CloudWatch Logs, and CloudTrail data events.
- Apply short log retention appropriate to a lab unless evidence preservation requires longer.
- Avoid high-cardinality custom metrics.
- Require operator confirmation before deployment, attack simulation, failure injection, drift creation, or teardown.

## Definition of done

The project is complete only when infrastructure validation succeeds, every required control has a recorded result, failed tests have a remediation or accepted limitation, recovery measurements are documented, sensitive evidence is redacted, and the final architecture reflects what the experiments proved.
