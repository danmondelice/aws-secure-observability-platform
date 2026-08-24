# Issues and Fixes Log

Use one entry per unexpected behavior, failed validation, or architectural correction.

## ISSUE-001 — Project-name validation rejected the repository name

- Date/time (UTC): 2026-08-24
- Phase: Terraform network foundation
- Environment: Local speculative plan against `us-east-2`
- Symptom: Terraform rejected the default project name before planning resources.
- Expected behavior: The repository project name should satisfy the shared naming contract.
- Evidence: Variable validation reported that `aws-secure-observability-platform` exceeded 32 characters.
- Root cause: A project-wide 32-character limit was applied even though name limits vary by AWS service.
- Fix: Increased the shared project-name limit to 48 characters; future services with smaller limits will derive compact service-specific names.
- Retest result: `terraform validate` succeeded and the speculative plan completed with 39 additions, zero changes, and zero destroys.
- Architecture or runbook change: Validate shared identifiers independently from service-specific physical-name constraints.
- Status: resolved

## ISSUE-002 — Root-level validation did not inspect the Terraform module

- Date/time (UTC): 2026-08-24
- Phase: Network/audit telemetry final validation
- Environment: Local macOS workspace
- Symptom: A root-level `terraform validate` reported success even though a duplicate output existed under `terraform/`.
- Expected behavior: Final validation should inspect the module that contains the infrastructure configuration.
- Evidence: The AWS-backed plan, run from `terraform/`, rejected the duplicate `vpc_id` output.
- Root cause: Terraform was invoked from the repository root, which contains no root-module `.tf` files.
- Fix: Removed the duplicate and standardized validation and planning with `terraform/` as the working directory.
- Retest result: Module validation succeeded; the Phase 8 AWS-backed plan completed with 111 additions, zero changes, and zero destroys.
- Architecture or runbook change: Run Terraform lifecycle commands from the module directory or use the explicit `-chdir=terraform` option.
- Status: resolved

## ISSUE-003 — Telemetry KMS policies blocked service initialization

- Date/time (UTC): 2026-08-24
- Phase: Initial AWS deployment
- Environment: `lab`, `us-east-2`
- Symptom: CloudWatch log-group creation returned `AccessDeniedException`, and the security-alert KMS key rejected an invalid service principal.
- Expected behavior: CloudWatch Logs, EventBridge, SNS, and SQS should use their scoped customer-managed keys.
- Evidence: Terraform apply stopped on encrypted log groups and `MalformedPolicyDocumentException` for the security-alert key.
- Root cause: CloudWatch Logs service-principal calls did not satisfy the additional `kms:ViaService` condition, and the SQS service principal was incorrectly region-qualified.
- Fix: Retained the CloudWatch Logs principal and encryption-context restrictions while removing the incompatible `kms:ViaService` condition; changed the SQS principal to `sqs.amazonaws.com`.
- Retest result: Partial-state recovery succeeded: encrypted log groups, CloudTrail, VPC Flow Logs, WAF logging, encrypted SNS/SQS alert routing, RDS, and the application launch template were created.
- Architecture or runbook change: Validate KMS principal names and distinguish direct service-principal calls from identity calls routed through a service.
- Status: resolved

## ISSUE-004 — CloudWatch rejected the alarm-status widget

- Date/time (UTC): 2026-08-24
- Phase: Initial AWS deployment
- Environment: `lab`, `us-east-2`
- Symptom: `PutDashboard` rejected the alarm-status widget after the rest of the recovery deployment succeeded.
- Expected behavior: The operations dashboard should summarize all configured alarm states.
- Evidence: CloudWatch reported that the metric widget had neither metrics nor a valid single-alarm annotation.
- Root cause: The widget used the metric-widget alarm-annotation schema for a multi-alarm status summary; metric widgets support only one alarm annotation.
- Fix: Changed the widget type to `alarm`, supplied the alarm ARN list through the `alarms` property, and sorted it by state-update time.
- Retest result: A dashboard-only recovery plan added exactly one resource with zero changes and zero destroys; CloudWatch accepted the corrected dashboard.
- Architecture or runbook change: Use CloudWatch alarm-status widgets for multi-alarm summaries and metric widgets for metric series or a single alarm annotation.
- Status: resolved

## ISSUE-005 — Amazon Linux curl package conflict stopped application bootstrap

- Date/time (UTC): 2026-08-24
- Phase: Initial AWS deployment
- Environment: `lab`, `us-east-2`
- Symptom: Both Auto Scaling instances were running and managed by Systems Manager, but ALB health checks failed and `/health` returned HTTP 502.
- Expected behavior: Bootstrap should install dependencies, create the systemd service, and expose a healthy application on the target port.
- Evidence: Systems Manager diagnostics showed a DNF conflict between the preinstalled `curl-minimal` package and requested `curl`; the application service and log file did not exist.
- Root cause: Bootstrap requested the full `curl` package even though Amazon Linux 2023 already provides the compatible `curl-minimal` command.
- Fix: Removed `curl` from the DNF package list while retaining use of the preinstalled curl-compatible command.
- Retest result: Pending launch-template rollout and ALB health verification.
- Architecture or runbook change: Treat base-AMI package inventory as a deployment dependency and validate bootstrap on the exact selected AMI family.
- Status: open

## Entry template

### ISSUE-000 — Short title

- Date/time (UTC):
- Phase:
- Environment:
- Symptom:
- Expected behavior:
- Evidence:
- Root cause:
- Fix:
- Retest result:
- Architecture or runbook change:
- Status: open / resolved / accepted
