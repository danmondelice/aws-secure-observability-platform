resource "aws_cloudwatch_log_metric_filter" "security_group_changes" {
  name           = "${local.physical_name_prefix}-security-group-changes"
  log_group_name = aws_cloudwatch_log_group.cloudtrail.name
  pattern        = "{ ($.eventName = AuthorizeSecurityGroupIngress) || ($.eventName = AuthorizeSecurityGroupEgress) || ($.eventName = RevokeSecurityGroupIngress) || ($.eventName = RevokeSecurityGroupEgress) || ($.eventName = CreateSecurityGroup) || ($.eventName = DeleteSecurityGroup) }"
  metric_transformation {
    name          = "SecurityGroupChanges"
    namespace     = "${var.project_name}/Audit"
    value         = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_metric_alarm" "security_group_changes" {
  alarm_name          = "${local.physical_name_prefix}-security-group-change"
  alarm_description   = "A security group was created, deleted, or had ingress/egress rules changed."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  threshold           = 1
  metric_name         = "SecurityGroupChanges"
  namespace           = "${var.project_name}/Audit"
  period              = 60
  statistic           = "Sum"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.operations.arn]
  ok_actions          = [aws_sns_topic.operations.arn]
}

resource "aws_cloudwatch_log_metric_filter" "cloudtrail_changes" {
  name           = "${local.physical_name_prefix}-cloudtrail-changes"
  log_group_name = aws_cloudwatch_log_group.cloudtrail.name
  pattern        = "{ ($.eventName = CreateTrail) || ($.eventName = UpdateTrail) || ($.eventName = DeleteTrail) || ($.eventName = StartLogging) || ($.eventName = StopLogging) || ($.eventName = PutEventSelectors) }"
  metric_transformation {
    name          = "CloudTrailChanges"
    namespace     = "${var.project_name}/Audit"
    value         = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_metric_alarm" "cloudtrail_changes" {
  alarm_name          = "${local.physical_name_prefix}-cloudtrail-change"
  alarm_description   = "CloudTrail configuration or logging state changed. Investigate immediately."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  threshold           = 1
  metric_name         = "CloudTrailChanges"
  namespace           = "${var.project_name}/Audit"
  period              = 60
  statistic           = "Sum"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.operations.arn]
  ok_actions          = [aws_sns_topic.operations.arn]
}
