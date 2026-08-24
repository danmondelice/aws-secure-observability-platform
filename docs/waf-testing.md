# AWS WAF Controlled Validation Runbook

Use this runbook only against the AWS resources created for this project. Do not run these requests against third-party systems. Terraform configuration and a successful plan do not prove that WAF works; retain the control statuses as `planned` until deployment and runtime evidence are complete.

## Control design

The regional web ACL is associated with the Application Load Balancer and defaults to allowing requests that do not match a blocking rule. Evaluation order is:

1. `AWSManagedRulesSQLiRuleSet`
2. `AWSManagedRulesCommonRuleSet`
3. `AWSManagedRulesKnownBadInputsRuleSet`
4. per-source-IP rate rule: 100 requests over a 60-second evaluation window

AWS WAF rate enforcement is approximate, not an exact request counter. Detection and release can lag the configured rate. The test therefore records observed allowed and blocked totals instead of claiming that request 101 must be the first block.

Blocked-request logs go to an encrypted CloudWatch log group. Query strings and `Authorization` headers are redacted, sampling is disabled, and allowed requests are dropped from detailed logs to limit sensitive data and cost. CloudWatch WAF metrics still show allowed and blocked totals.

## Preconditions

- Terraform has been applied and the ALB targets are healthy.
- The WAF web ACL is associated with the intended lab ALB.
- You own the target and have recorded the UTC test window.
- The source public IP and account identifiers will be redacted from committed evidence.
- Run the three-request security test before the rate test so an active rate block does not affect its baseline.

## SQL injection and XSS validation

```bash
CONFIRM_OWNED_AWS_LAB=yes \
  tests/waf-security-tests.sh "$(terraform -chdir=terraform output -raw alb_url)"
```

Expected result:

- normal `/` request: HTTP 200;
- encoded SQL injection-shaped query: HTTP 403;
- encoded XSS-shaped query: HTTP 403.

## Bounded rate validation

The script is sequential, defaults to 130 requests, and refuses values over 200.

```bash
CONFIRM_OWNED_AWS_LAB=yes WAF_TEST_REQUESTS=130 \
  tests/waf-rate-test.sh "$(terraform -chdir=terraform output -raw alb_url)"
```

At least one 403 is expected, but the exact transition request is not guaranteed. If no block appears, wait briefly, verify the Web ACL association and configured threshold, and perform only one documented retest.

## WAF Logs Insights query

```text
fields @timestamp,
       action,
       terminatingRuleId,
       terminatingRuleType,
       httpRequest.clientIp,
       httpRequest.country,
       httpRequest.httpMethod,
       httpRequest.uri,
       labels
| filter action = "BLOCK"
| sort @timestamp desc
| limit 100
```

Match each request to its UTC test window, HTTP status, terminating rule, WAF metric increase, alarm transition, and notification. Redaction intentionally prevents the detailed query payload from appearing in logs; the test command, timestamp, HTTP 403, rule identifier, and metrics together form the evidence.

## Production rollout lesson

For real production traffic, introduce new managed-rule versions in `Count` mode, study false positives and labels, add narrowly justified exclusions, and only then move validated rules to block. This lab defaults to block because it is isolated and its purpose is controlled validation.

## Interview sequence

Remember **Baseline → Send → Block → Correlate → Tune**:

1. **Baseline:** verify normal traffic returns 200 and note WAF metrics.
2. **Send:** issue one harmless encoded SQLi pattern, one harmless encoded XSS pattern, or a bounded rate sequence.
3. **Block:** record HTTP 403 without attempting bypasses or exploitation.
4. **Correlate:** match UTC time, terminating rule, redacted WAF log, metric, alarm, and SNS notification.
5. **Tune:** assess false positives, thresholds, rule order, and production Count-to-Block rollout.

Interview summary:

> I associated a regional AWS WAF web ACL with the ALB, used AWS-managed SQL injection, core, and known-bad-input protections, and added per-IP rate limiting. I validated normal availability and then sent bounded, non-destructive test patterns. I correlated each 403 response with the terminating WAF rule, CloudWatch metrics, encrypted redacted logs, and the alarm notification. I treated rate limiting as approximate and documented how I would deploy managed-rule changes in Count mode before blocking production traffic.
