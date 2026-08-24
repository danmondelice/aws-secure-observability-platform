# Security Detection and Drift Runbook

Phase 9 builds the detection pipeline; it does not claim that findings or drift alerts have been proven. Runtime statuses remain `planned` until the infrastructure is deployed and evidence is collected in an explicitly approved test window.

## Architecture

```text
GuardDuty medium+ finding ---------\
AWS Config NON_COMPLIANT transition ---> EventBridge ---> encrypted security SNS topic
Security Hub failed medium+ finding --/          \
                                                   -> encrypted SQS dead-letter queue on delivery failure
```

GuardDuty enables the base detector plus S3 data-event monitoring, EBS malware protection, and EC2 runtime monitoring with managed agent configuration. AWS Config continuously records supported resources, stores KMS-encrypted history and snapshots in the audit bucket, and evaluates seven AWS managed rules. Security Hub and Security Hub CSPM are enabled, with the AWS Foundational Security Best Practices standard selected explicitly rather than accepting legacy default standards.

## Read-only post-deployment verification

Use temporary AWS credentials. The script prints service states only and does not retrieve finding bodies, IP addresses, account IDs, or resource details.

```bash
AWS_PROFILE=school645 AWS_REGION=us-east-2 tests/security-posture-check.sh
```

Manual read-only checks should confirm:

- GuardDuty detector status and every feature returned by the service;
- AWS Config recorder state, last delivery status, and all seven rule states;
- Security Hub CSPM hub state and enabled FSBP subscription;
- Security Hub V2 account state;
- each EventBridge rule has the encrypted security topic as its target;
- the security-event dead-letter queue has no unexpected messages.

Finding bodies can include addresses, resource identifiers, threat details, and account metadata. Summarize first and do not commit raw output until it has been reviewed and redacted.

## Planned GuardDuty evidence exercise

Use only AWS-supported sample findings in a separately approved test window. Do not generate real malicious traffic. The required evidence is:

1. UTC start and end time;
2. finding title beginning with the AWS sample marker and its finding type;
3. direct GuardDuty EventBridge rule match;
4. sanitized SNS notification;
5. successful EventBridge invocation with no DLQ message;
6. corresponding Security Hub ingestion, allowing for service propagation time.

Prioritize any `AttackSequence:` sample when reviewing results because it represents a correlated multi-step sequence. Sample findings prove the event pipeline and analyst workflow; they do not prove that an actual compromise was detected.

## Planned AWS Config drift exercise

The drift test requires a separate explicit operator approval because it temporarily changes infrastructure. The approved design is a narrowly timed, lab-only security-group change followed by immediate restoration to the Terraform-defined state.

Required evidence:

1. pre-change compliant state;
2. recorded UTC change window and CloudTrail attribution;
3. AWS Config `NON_COMPLIANT` transition for the restricted-SSH rule;
4. EventBridge match and sanitized SNS notification;
5. immediate rollback;
6. return to `COMPLIANT`;
7. Terraform plan showing no remaining drift.

Never leave a public SSH rule in place while waiting for screenshots or asynchronous evaluation. The evidence is invalid if rollback and final plan verification are missing.

## Triage workflow

Remember **Detect → Route → Triage → Correlate → Improve**:

1. **Detect:** GuardDuty identifies threat activity, Config identifies drift, and Security Hub CSPM identifies failed controls.
2. **Route:** EventBridge filters medium-or-higher active findings and noncompliant transitions into a dedicated encrypted topic.
3. **Triage:** confirm source, finding type, severity, affected resource, current workflow state, and whether the event is a sample.
4. **Correlate:** use CloudTrail, VPC Flow Logs, WAF logs, application telemetry, and Config history around the same UTC window.
5. **Improve:** contain or roll back, update Terraform or the runbook, retest, and record what changed.

Interview summary:

> I built a layered detection pipeline with GuardDuty for threats, AWS Config for configuration drift, and Security Hub for centralized posture and correlation. EventBridge filters actionable findings into a dedicated KMS-encrypted SNS topic, and failed deliveries go to an encrypted dead-letter queue with their own alarms. I designed tests around AWS-supported sample findings and a reversible lab-only drift event, then correlated the alerts with CloudTrail, Flow Logs, WAF, and application telemetry.
