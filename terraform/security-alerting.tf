resource "aws_sns_topic" "security" {
  name              = local.security_topic_name
  display_name      = "ASOP Security"
  kms_master_key_id = aws_kms_key.security_alerts.arn

  tags = {
    Name = "${local.name_prefix}-security-alerts"
  }
}

resource "aws_sns_topic_subscription" "security_email" {
  count = var.security_alert_email == null ? 0 : 1

  topic_arn = aws_sns_topic.security.arn
  protocol  = "email"
  endpoint  = var.security_alert_email
}

data "aws_iam_policy_document" "security_topic" {
  statement {
    sid    = "AllowAccountAdministration"
    effect = "Allow"
    actions = [
      "sns:DeleteTopic",
      "sns:GetTopicAttributes",
      "sns:ListSubscriptionsByTopic",
      "sns:Publish",
      "sns:SetTopicAttributes",
      "sns:Subscribe",
    ]
    resources = [aws_sns_topic.security.arn]

    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  statement {
    sid       = "AllowProjectEventBridgeRules"
    effect    = "Allow"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.security.arn]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:${data.aws_partition.current.partition}:events:${var.aws_region}:${data.aws_caller_identity.current.account_id}:rule/${local.physical_name_prefix}-security-*"]
    }
  }
}

resource "aws_sns_topic_policy" "security" {
  arn    = aws_sns_topic.security.arn
  policy = data.aws_iam_policy_document.security_topic.json
}

resource "aws_sqs_queue" "security_events_dlq" {
  name                              = local.security_dlq_name
  message_retention_seconds         = 1209600
  receive_wait_time_seconds         = 20
  visibility_timeout_seconds        = 30
  kms_master_key_id                 = aws_kms_key.security_alerts.arn
  kms_data_key_reuse_period_seconds = 300

  tags = {
    Name = "${local.name_prefix}-security-events-dlq"
  }
}

data "aws_iam_policy_document" "security_events_dlq" {
  statement {
    sid       = "AllowProjectEventBridgeFailures"
    effect    = "Allow"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.security_events_dlq.arn]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:${data.aws_partition.current.partition}:events:${var.aws_region}:${data.aws_caller_identity.current.account_id}:rule/${local.physical_name_prefix}-security-*"]
    }
  }
}

resource "aws_sqs_queue_policy" "security_events_dlq" {
  queue_url = aws_sqs_queue.security_events_dlq.id
  policy    = data.aws_iam_policy_document.security_events_dlq.json
}

resource "aws_cloudwatch_event_rule" "guardduty" {
  name        = "${local.physical_name_prefix}-security-guardduty"
  description = "Route medium and higher GuardDuty findings"
  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      severity = [{ numeric = [">=", 4] }]
    }
  })
}

resource "aws_cloudwatch_event_target" "guardduty" {
  rule      = aws_cloudwatch_event_rule.guardduty.name
  target_id = "EncryptedSecurityTopic"
  arn       = aws_sns_topic.security.arn

  dead_letter_config {
    arn = aws_sqs_queue.security_events_dlq.arn
  }

  input_transformer {
    input_paths = {
      account  = "$.account"
      finding  = "$.detail.id"
      region   = "$.region"
      severity = "$.detail.severity"
      title    = "$.detail.title"
      type     = "$.detail.type"
    }
    input_template = <<-EOT
      {"source":"GuardDuty","account":"<account>","region":"<region>","severity":"<severity>","type":"<type>","title":"<title>","findingId":"<finding>"}
    EOT
  }

  depends_on = [
    aws_sns_topic_policy.security,
    aws_sqs_queue_policy.security_events_dlq,
  ]
}

resource "aws_cloudwatch_event_rule" "config_noncompliant" {
  name        = "${local.physical_name_prefix}-security-config-noncompliant"
  description = "Route AWS Config transitions to noncompliant"
  event_pattern = jsonencode({
    source      = ["aws.config"]
    detail-type = ["Config Rules Compliance Change"]
    detail = {
      messageType = ["ComplianceChangeNotification"]
      newEvaluationResult = {
        complianceType = ["NON_COMPLIANT"]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "config_noncompliant" {
  rule      = aws_cloudwatch_event_rule.config_noncompliant.name
  target_id = "EncryptedSecurityTopic"
  arn       = aws_sns_topic.security.arn

  dead_letter_config {
    arn = aws_sqs_queue.security_events_dlq.arn
  }

  input_transformer {
    input_paths = {
      account       = "$.account"
      compliance    = "$.detail.newEvaluationResult.complianceType"
      region        = "$.region"
      resource_id   = "$.detail.resourceId"
      resource_type = "$.detail.resourceType"
      rule          = "$.detail.configRuleName"
      time          = "$.time"
    }
    input_template = <<-EOT
      {"source":"AWS Config","account":"<account>","region":"<region>","rule":"<rule>","compliance":"<compliance>","resourceType":"<resource_type>","resourceId":"<resource_id>","time":"<time>"}
    EOT
  }

  depends_on = [
    aws_sns_topic_policy.security,
    aws_sqs_queue_policy.security_events_dlq,
  ]
}

resource "aws_cloudwatch_event_rule" "securityhub" {
  name        = "${local.physical_name_prefix}-security-securityhub"
  description = "Route active failed medium-or-higher Security Hub CSPM findings"
  event_pattern = jsonencode({
    source      = ["aws.securityhub"]
    detail-type = ["Security Hub Findings - Imported"]
    detail = {
      findings = {
        Compliance  = { Status = ["FAILED"] }
        RecordState = ["ACTIVE"]
        Severity    = { Label = ["MEDIUM", "HIGH", "CRITICAL"] }
        Workflow    = { Status = ["NEW", "NOTIFIED"] }
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "securityhub" {
  rule      = aws_cloudwatch_event_rule.securityhub.name
  target_id = "EncryptedSecurityTopic"
  arn       = aws_sns_topic.security.arn

  dead_letter_config {
    arn = aws_sqs_queue.security_events_dlq.arn
  }

  input_transformer {
    input_paths = {
      account    = "$.detail.findings[0].AwsAccountId"
      finding_id = "$.detail.findings[0].Id"
      resource   = "$.detail.findings[0].Resources[0].Id"
      severity   = "$.detail.findings[0].Severity.Label"
      title      = "$.detail.findings[0].Title"
    }
    input_template = <<-EOT
      {"source":"Security Hub CSPM","account":"<account>","severity":"<severity>","title":"<title>","resource":"<resource>","findingId":"<finding_id>"}
    EOT
  }

  depends_on = [
    aws_sns_topic_policy.security,
    aws_sqs_queue_policy.security_events_dlq,
  ]
}

locals {
  security_event_rules = {
    guardduty   = aws_cloudwatch_event_rule.guardduty.name
    config      = aws_cloudwatch_event_rule.config_noncompliant.name
    securityhub = aws_cloudwatch_event_rule.securityhub.name
  }
}

resource "aws_cloudwatch_metric_alarm" "security_event_delivery" {
  for_each = local.security_event_rules

  alarm_name          = "${local.physical_name_prefix}-${each.key}-event-delivery-failed"
  alarm_description   = "EventBridge could not deliver a ${each.key} security event; inspect the encrypted DLQ."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  threshold           = 1
  metric_name         = "FailedInvocations"
  namespace           = "AWS/Events"
  period              = 60
  statistic           = "Sum"
  treat_missing_data  = "notBreaching"

  dimensions = {
    RuleName = each.value
  }

  alarm_actions = [aws_sns_topic.operations.arn]
  ok_actions    = [aws_sns_topic.operations.arn]
}
