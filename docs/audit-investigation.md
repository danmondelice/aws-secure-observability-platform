# Network and Audit Investigation Runbook

Use this runbook only after Phase 7 has been applied. Record UTC timestamps and redact account identifiers, public addresses, subscriber endpoints, and sensitive request parameters before committing evidence.

## What this phase proves

- VPC traffic decisions can be investigated through accepted and rejected flow records.
- AWS management-plane changes can be attributed to an identity, API call, time, Region, and source address.
- Audit records have encryption, private storage, versioning, integrity validation, access logging, and defined retention.
- Selected high-value changes produce alarms rather than relying on manual log review.

Terraform configuration alone does not prove delivery, detection, or alerting. Those claims remain `planned` until these checks produce runtime evidence.

## Post-deployment verification

```bash
aws cloudtrail get-trail-status \
  --name "$(terraform -chdir=terraform output -raw cloudtrail_name)" \
  --query '{Logging:IsLogging,LatestDeliveryTime:LatestDeliveryTime,LatestCloudWatchLogsDeliveryTime:LatestCloudWatchLogsDeliveryTime}'

aws ec2 describe-flow-logs \
  --filter Name=resource-id,Values="$(terraform -chdir=terraform output -raw vpc_id)"
```

Do not record a pass until `IsLogging` is true, recent delivery timestamps exist, and the Flow Log reports an active delivery state.

## CloudTrail investigation query

Run against the CloudTrail log group in CloudWatch Logs Insights:

```text
fields @timestamp,
       userIdentity.arn as actor,
       eventSource,
       eventName,
       awsRegion,
       sourceIPAddress,
       errorCode,
       requestParameters
| filter eventName like /^(Create|Delete|Update|Modify|Put|Authorize|Revoke|Start|Stop)/
| sort @timestamp desc
| limit 100
```

For the AUD-01 experiment, make one documented and reversible lab-only change. Capture the event, verify the change alarm, and immediately return the resource to its Terraform-defined state.

## Rejected-flow investigation query

The dashboard provides a fast recent-REJECT view. For deeper analysis, parse the known custom record order:

```text
fields @timestamp, @message
| filter @message like / REJECT /
| parse @message '* * * * * * * * * * * * * * * * * * * * * * *' as version, account_id, interface_id, src_addr, dst_addr, src_port, dst_port, protocol, packets, bytes, start_time, end_time, action, log_status, vpc_id, subnet_id, instance_id, packet_src_addr, packet_dst_addr, region, az_id, flow_direction, traffic_path
| stats count(*) as rejected_flows, sum(bytes) as rejected_bytes by src_addr, dst_addr, dst_port, protocol
| sort rejected_flows desc
| limit 100
```

For NET-03, generate only a bounded denied connection inside the lab. Match the test timestamp, source, destination, port, and `REJECT` result. A rejected record proves the network control made a deny decision; it does not by itself prove malicious intent.

## Evidence checklist

- Hypothesis and expected result
- Exact reversible action or bounded connection test
- UTC start/end time
- CloudTrail event or VPC Flow Log record
- Alarm state transition and SNS delivery when applicable
- Redacted screenshots or CLI output
- Pass/fail conclusion
- Remediation and retest if behavior differed from the hypothesis

## Interview summary

> I implemented a multi-Region CloudTrail for management-plane accountability and VPC Flow Logs for network decisions. I protected the audit record with KMS encryption, private versioned S3 storage, TLS-only access, integrity validation, access logging, and lifecycle retention. I then used CloudWatch queries and change alarms to identify who changed a resource and to correlate denied connections with their source, destination, port, and timestamp.
