# Interview Guide

This is a memory aid, not a script to recite word for word. Lead with the problem, explain the decisions, then prove the controls with evidence.

## The six steps to remember

Use the mnemonic **Requirements → Architecture → Controls → Break → Observe → Improve**.

1. **Requirements** — availability, no public servers, no SSH, auditable changes, security detection, and actionable alerts.
2. **Architecture** — public ALB; private Auto Scaling application tier; isolated Multi-AZ RDS; Terraform for reproducibility.
3. **Controls** — security groups, IAM roles, IMDSv2, KMS, Secrets Manager, WAF, CloudTrail, Config, GuardDuty, Flow Logs, CloudWatch, and SNS.
4. **Break** — controlled SQLi/XSS/rate tests, application 500s, stopped service, terminated instance, CPU pressure, denied IAM calls, and configuration drift.
5. **Observe** — correlate request IDs, WAF logs, ALB metrics, application logs, CloudTrail events, Config evaluations, GuardDuty findings, Flow Logs, alarm transitions, and SNS delivery.
6. **Improve** — fix anything that failed, retest it, record recovery time, and update the architecture or runbook from the evidence.

## Thirty-second version

> I built a production-style AWS application platform with Terraform. An Application Load Balancer fronts a two-AZ Auto Scaling EC2 tier in private subnets, with an encrypted Multi-AZ RDS database in isolated subnets. I removed SSH in favor of Systems Manager, required IMDSv2, used narrowly scoped IAM and RDS-managed Secrets Manager credentials, and added CloudWatch dashboards, logs, alarms, and encrypted SNS notifications. The differentiator is that I deliberately test each claim: I generate controlled attacks and failures, correlate the telemetry, measure recovery, and harden anything the evidence shows is weak.

## Two-minute version

Use this order:

1. **Business problem:** a financial-services application needed high availability, private compute/database tiers, auditable administration, security detection, and operational alerting.
2. **Infrastructure:** Terraform creates two-AZ public, application, and database subnet tiers. The ALB is the only public application entry point. EC2 instances receive no public IP and have no SSH ingress.
3. **Availability:** the application ASG maintains two instances, uses ALB health checks for replacement, enables target-tracking scaling, and performs rolling launch-template refreshes with rollback settings.
4. **Identity and data:** EC2 uses an instance role and Systems Manager. IMDSv2 is required. RDS is private, encrypted, Multi-AZ, and uses RDS-managed Secrets Manager credentials under a rotating customer-managed KMS key.
5. **Observability:** CloudWatch Agent sends structured application/host logs and CPU, memory, and disk metrics. The dashboard combines ALB, ASG, EC2-agent, RDS, alarms, and recent errors. Alarms use explicit missing-data handling and M-of-N evaluation before encrypted SNS notification.
6. **Proof:** explain one attack test, one failure test, one denied authorization test, and the evidence used to reach a conclusion.
7. **Improvement:** mention a real correction from the issues log or architecture decisions rather than claiming the first design was perfect.

## Build sequence to remember

| Phase | What was built | Why it matters | Proof before commit |
|---|---|---|---|
| 1 | Requirements and validation matrix | Prevents vague security claims | Every control has a planned test and evidence type |
| 2 | Flask API | Provides health, readiness, logs, and failure surfaces | Eleven local tests and live Gunicorn health check |
| 3 | VPC and security groups | Separates public, app, and DB trust zones | Valid Terraform plan and no public-IP/SSH configuration |
| 4 | ALB and private ASG | Availability and self-healing | ELB health mode, two AZs, IMDSv2, encrypted EBS, rolling refresh |
| 5 | RDS, Secrets Manager, KMS | Private encrypted data and credential lifecycle | Managed password, exact-secret IAM, KMS service/context restrictions |
| 6 | CloudWatch and SNS | Detection, investigation, and notification | Encrypted logs/topic, dashboard, M-of-N alarms, explicit missing-data policy |
| 7 | VPC Flow Logs and CloudTrail | Network evidence and management-plane accountability | Encrypted flow/audit logs, integrity validation, change alarms, and investigation queries |
| Later | WAF, Config, GuardDuty, Security Hub | Prevention, drift detection, and threat findings | Controlled experiments with timestamps and redacted artifacts |

### Phase 7 interview steps

Remember **Capture → Protect → Detect → Investigate → Attribute**:

1. **Capture:** VPC Flow Logs record accepted and rejected traffic; a multi-Region CloudTrail records all read/write management events and global events.
2. **Protect:** customer-managed KMS encryption, private versioned S3 storage, TLS-only bucket policies, server access logging, lifecycle retention, and CloudTrail digest validation protect the audit record.
3. **Detect:** CloudWatch metric filters and SNS-backed alarms identify security-group changes and CloudTrail configuration changes.
4. **Investigate:** Logs Insights narrows activity by time, event, actor, source IP, error, interface, port, and ACCEPT/REJECT result.
5. **Attribute:** CloudTrail's identity, API, Region, time, request parameters, and source address establish who changed what and when.

## Design decisions interviewers may ask about

### Why an ALB and Auto Scaling group?

The ALB performs health checks and removes unhealthy targets. The ASG is configured with `ELB` health checks, so an application failure can trigger instance replacement rather than leaving an EC2-healthy but application-unhealthy server running.

### Why two NAT gateways?

One per AZ avoids routing both private application subnets through a single zonal dependency. The lab can switch to one NAT to reduce cost, but that tradeoff is explicit and not described as highly available.

### Why no SSH?

Instances have no public IP, key pair, or port 22 rule. Systems Manager uses the instance role and outbound TLS, reducing exposed administration paths and key-management burden.

### Why IMDSv2?

Requiring tokens blocks IMDSv1 requests and reduces exposure to SSRF-style metadata credential theft. The test must show tokenless failure and token-authenticated success.

### Why RDS-managed credentials?

RDS generates and rotates the master password in Secrets Manager, so Terraform never generates or receives plaintext. IAM is scoped to one secret and KMS decryption is restricted to Secrets Manager plus that secret's encryption context. The application still needs a separate least-privilege database user before it can be called production-ready.

### Why M-of-N alarms?

Two breaching points out of three reduce noise from a single incomplete or transient datapoint. Missing data is handled according to metric semantics: missing error counts are non-breaching, while missing health/capacity data is breaching or explicitly visible.

### Why p99 latency?

Average latency hides slow requests. P99 makes tail latency visible. The initial one-second threshold is a starting hypothesis and must be tuned after baseline measurements.

### Why customer-managed KMS keys?

They allow service and encryption-context restrictions that are visible in Terraform and auditable through CloudTrail. Separate keys limit the blast radius between database, log, and notification data.

## Evidence pattern for every experiment

Say this sequence aloud:

> Hypothesis, controlled action, timestamp, telemetry source, observed result, pass or fail, remediation, retest.

Example:

> My hypothesis was that stopping the application would remove the instance from ALB service and alert operations. I used an approved SSM command at a recorded UTC time, observed the target become unhealthy, confirmed the healthy-host alarm and SNS notification, then restored the service and measured the alarm returning to OK. If replacement or alert timing missed the objective, I adjusted the grace period or alarm and repeated the test.

## Do not overclaim

- Do not say infrastructure is deployed until `terraform apply` and runtime verification succeed.
- Do not say HTTPS is enabled until ACM, the HTTPS listener, and redirect are applied and tested.
- Do not say database least privilege is complete while the application can access a master credential.
- Do not say an alarm works merely because Terraform created it; trigger it and capture the transition and notification.
- Do not say WAF, GuardDuty, Config, CloudTrail, or Flow Logs work until their controlled tests produce evidence.
- Redact account IDs, ARNs where appropriate, email addresses, IP addresses, tokens, and secret values before committing evidence.

## Questions to practice

1. What happens when one EC2 instance or Availability Zone fails?
2. Why can the application instances reach AWS APIs but the Internet cannot initiate traffic to them?
3. How does ALB health differ from EC2 status checks?
4. What does IMDSv2 protect against, and how did you test it?
5. Why is the database not publicly accessible, and what security-group path permits it?
6. How are credentials generated, encrypted, authorized, rotated, and audited?
7. Why did you choose each alarm threshold and missing-data behavior?
8. How would you investigate a spike in target 5xx responses?
9. What costs the most in this lab, and how would you reduce cost without hiding the availability tradeoff?
10. What failed during the project, what evidence identified the cause, and what did you change?
