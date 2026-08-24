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
