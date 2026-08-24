# Control Validation Matrix

Status values: `planned`, `pass`, `fail`, `blocked`, or `not-run`.

| ID | Control claim | Controlled test | Required evidence | Initial status |
|---|---|---|---|---|
| NET-01 | EC2 is not Internet-addressable | Inspect instance addressing, routes, and ingress; attempt only an authorized lab connectivity check | Terraform/CLI output and connection result | planned |
| NET-02 | RDS accepts traffic only from the app tier | Inspect public accessibility and SG references; test from approved and unapproved lab sources | Configuration and connection results | planned |
| NET-03 | Rejected traffic is observable | Generate a controlled denied connection within the lab | Matching Flow Log `REJECT` record | planned |
| IAM-01 | App role has only required access | Retrieve the scoped secret, then call a harmless unauthorized read API | Success plus `AccessDenied` evidence | planned |
| META-01 | IMDSv1 is unusable | Query metadata without a token, then repeat with IMDSv2 | Failure and token-authenticated success | planned |
| SEC-01 | SQL injection patterns are blocked | Send a benign encoded SQLi test string to the lab endpoint | HTTP 403 and matching WAF log | planned |
| SEC-02 | XSS patterns are blocked | Send a benign encoded XSS test string | HTTP 403 and matching WAF log | planned |
| SEC-03 | Excessive requests are rate-limited | Run a bounded request burst above the configured threshold | Allowed/blocked counts and WAF log | planned |
| SEC-04 | Supported threat simulations alert | Generate AWS-supported GuardDuty sample findings | Finding and routed notification | planned |
| SEC-05 | Actionable posture findings are centralized | Observe an active failed medium-or-higher FSBP control finding | Security Hub finding and sanitized routed notification | planned |
| AUD-01 | Management changes are attributable | Make one documented reversible lab configuration change | CloudTrail principal, time, region, source, API, and parameters | planned |
| CFG-01 | Public SSH drift is detected | Temporarily add a narrowly timed lab-only noncompliant rule and immediately revert it | Config transition, alert, rollback, and compliant state | planned |
| ENC-01 | Data stores and telemetry are encrypted | Inspect RDS, EBS, secrets, logs, trail bucket, and SNS configuration | Configuration output with key identifiers redacted | planned |
| MON-01 | Application failure alerts | Invoke the test-only 500 endpoint above a bounded threshold | Metric graph, alarm transition, and notification | planned |
| MON-02 | Unhealthy targets alert and drain | Stop the app service through an approved SSM runbook | ALB health, alarm transition, and recovery | planned |
| MON-03 | CPU pressure alerts | Generate bounded CPU load with automatic timeout | Metric, alarm, notification, and recovery | planned |
| RES-01 | ASG replaces a failed instance | Terminate one ASG instance during an approved test window | Timeline from termination to healthy replacement | planned |
| RES-02 | Capacity scales under load | Generate bounded load if scaling is enabled | Scaling activity, instance count, latency, and recovery | planned |

Raw evidence must not be committed until it has been reviewed and redacted. Each completed row will link to a dated report under `docs/experiments/`.
