resource "aws_sns_topic" "operations" {
  name              = local.notification_topic_name
  display_name      = "ASOP Operations"
  kms_master_key_id = aws_kms_key.notifications.arn

  tags = {
    Name = "${local.name_prefix}-operations-alerts"
  }
}

data "aws_iam_policy_document" "operations_topic" {
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
    resources = [aws_sns_topic.operations.arn]

    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  statement {
    sid       = "AllowProjectCloudWatchAlarms"
    effect    = "Allow"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.operations.arn]

    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values = [
        "arn:${data.aws_partition.current.partition}:cloudwatch:${var.aws_region}:${data.aws_caller_identity.current.account_id}:alarm:${local.physical_name_prefix}-*"
      ]
    }
  }
}

resource "aws_sns_topic_policy" "operations" {
  arn    = aws_sns_topic.operations.arn
  policy = data.aws_iam_policy_document.operations_topic.json
}

resource "aws_sns_topic_subscription" "email" {
  count = var.alert_email == null ? 0 : 1

  topic_arn = aws_sns_topic.operations.arn
  protocol  = "email"
  endpoint  = var.alert_email
}
