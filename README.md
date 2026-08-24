# AWS Secure Observability Platform

A production-style AWS security and observability lab built with Terraform.

The project demonstrates more than resource deployment: every material security claim is paired with a controlled test, and every monitoring claim is paired with observable evidence.

## Interview story

> I deployed a production-style application, implemented security and observability controls, deliberately attacked or broke parts of it, proved whether the controls worked, investigated the resulting telemetry, and improved the architecture based on the evidence.

## Status

Phase 4 — ALB and private EC2 Auto Scaling application tier.

No AWS resources have been created yet.

The current Terraform configuration defines the multi-AZ network, public ALB, and private Auto Scaling application tier. It has not been applied to AWS.

## Planned architecture

```text
Internet
   |
Route 53 (optional custom domain)
   |
AWS WAF
   |
Application Load Balancer (public subnets, two AZs)
   |
Auto Scaling EC2 application tier (private subnets, no SSH)
   |
RDS (private DB subnets, encrypted, not publicly accessible)

Security telemetry: CloudTrail, AWS Config, GuardDuty, Security Hub,
WAF logs, and VPC Flow Logs -> EventBridge / CloudWatch -> SNS

Operations telemetry: ALB, EC2, RDS, and application metrics/logs
-> CloudWatch dashboards and alarms -> SNS
```

## Delivery phases

1. Project charter, requirements, evidence plan, and cost controls
2. Small Flask application and local tests
3. VPC, public/private subnets, routing, and network controls
4. ALB and private EC2 Auto Scaling application tier
5. Private RDS and runtime-only secret retrieval
6. CloudWatch logs, metrics, dashboard, alarms, and SNS
7. VPC Flow Logs and CloudTrail
8. WAF and controlled attack tests
9. GuardDuty, AWS Config, and Security Hub integrations
10. Failure, recovery, authorization, metadata, and network tests
11. Evidence review, remediation, final validation, and interview write-up

## Evidence standard

Each experiment records:

- hypothesis and expected result;
- exact test command or controlled action;
- UTC start and end time;
- relevant resource identifiers, with account details redacted;
- logs, metrics, events, screenshots, or CLI output;
- actual result and pass/fail conclusion;
- remediation and retest when a control fails.

See [docs/requirements.md](docs/requirements.md), [docs/control-validation-matrix.md](docs/control-validation-matrix.md), and [ISSUES.md](ISSUES.md).

## Local application

```bash
python3 -m venv .venv
.venv/bin/python -m pip install -r app/requirements-dev.txt
.venv/bin/pytest
.venv/bin/gunicorn --config app/gunicorn.conf.py 'app.app:app'
```

The controlled HTTP 500 endpoint is disabled by default. Enable it only during an approved experiment:

```bash
ENABLE_FAILURE_ENDPOINTS=true .venv/bin/gunicorn --config app/gunicorn.conf.py 'app.app:app'
```

## Safety boundaries

- Run experiments only against resources created for this lab.
- Use AWS-supported sample findings for GuardDuty.
- Do not perform destructive, evasive, persistence, credential-theft, or third-party attack activity.
- Keep passwords, secret values, account IDs, public IP addresses, and subscriber endpoints out of Git.
- Require an explicit operator step for failure injection and drift tests.
- Destroy billable lab resources when a test cycle is complete.

## Repository layout

```text
.
├── app/
├── docs/
├── evidence/          # redacted evidence index; raw artifacts ignored
├── terraform/
├── tests/
├── .gitignore
├── ISSUES.md
└── README.md
```
