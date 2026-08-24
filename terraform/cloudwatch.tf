resource "aws_cloudwatch_log_group" "application" {
  name              = local.application_log_group_name
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.observability.arn
}

resource "aws_cloudwatch_log_group" "bootstrap" {
  name              = local.bootstrap_log_group_name
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.observability.arn
}

resource "aws_cloudwatch_log_group" "system" {
  name              = local.system_log_group_name
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.observability.arn
}

resource "aws_cloudwatch_log_group" "rds" {
  for_each = toset(["error", "general", "slowquery"])

  name              = "/aws/rds/instance/${local.physical_name_prefix}-mysql/${each.key}"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.observability.arn
}

locals {
  alarm_arns = [
    aws_cloudwatch_metric_alarm.alb_healthy_hosts.arn,
    aws_cloudwatch_metric_alarm.alb_unhealthy_hosts.arn,
    aws_cloudwatch_metric_alarm.alb_target_5xx_rate.arn,
    aws_cloudwatch_metric_alarm.alb_latency_p99.arn,
    aws_cloudwatch_metric_alarm.asg_in_service.arn,
    aws_cloudwatch_metric_alarm.app_memory.arn,
    aws_cloudwatch_metric_alarm.app_disk.arn,
    aws_cloudwatch_metric_alarm.rds_cpu.arn,
    aws_cloudwatch_metric_alarm.rds_connections.arn,
    aws_cloudwatch_metric_alarm.rds_free_storage.arn,
    aws_cloudwatch_metric_alarm.security_group_changes.arn,
    aws_cloudwatch_metric_alarm.cloudtrail_changes.arn,
  ]
}

resource "aws_cloudwatch_metric_alarm" "alb_healthy_hosts" {
  alarm_name          = "${local.physical_name_prefix}-alb-healthy-hosts-low"
  alarm_description   = "Fewer than two healthy application targets"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HealthyHostCount"
  statistic           = "Minimum"
  period              = 60
  evaluation_periods  = 3
  datapoints_to_alarm = 2
  threshold           = 2
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "breaching"

  dimensions = {
    LoadBalancer = aws_lb.app.arn_suffix
    TargetGroup  = aws_lb_target_group.app.arn_suffix
  }

  alarm_actions = [aws_sns_topic.operations.arn]
  ok_actions    = [aws_sns_topic.operations.arn]
}

resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_hosts" {
  alarm_name          = "${local.physical_name_prefix}-alb-unhealthy-hosts"
  alarm_description   = "At least one ALB target is unhealthy"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 3
  datapoints_to_alarm = 2
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.app.arn_suffix
    TargetGroup  = aws_lb_target_group.app.arn_suffix
  }

  alarm_actions = [aws_sns_topic.operations.arn]
  ok_actions    = [aws_sns_topic.operations.arn]
}

resource "aws_cloudwatch_metric_alarm" "alb_target_5xx_rate" {
  alarm_name          = "${local.physical_name_prefix}-alb-target-5xx-rate"
  alarm_description   = "Target HTTP 5xx rate exceeded 5 percent"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  datapoints_to_alarm = 2
  threshold           = 5
  treat_missing_data  = "notBreaching"

  metric_query {
    id          = "error_rate"
    expression  = "IF(requests > 0, target_5xx * 100 / requests, 0)"
    label       = "Target 5xx rate (%)"
    return_data = true
  }

  metric_query {
    id          = "target_5xx"
    return_data = false

    metric {
      namespace   = "AWS/ApplicationELB"
      metric_name = "HTTPCode_Target_5XX_Count"
      period      = 60
      stat        = "Sum"

      dimensions = {
        LoadBalancer = aws_lb.app.arn_suffix
        TargetGroup  = aws_lb_target_group.app.arn_suffix
      }
    }
  }

  metric_query {
    id          = "requests"
    return_data = false

    metric {
      namespace   = "AWS/ApplicationELB"
      metric_name = "RequestCount"
      period      = 60
      stat        = "Sum"

      dimensions = {
        LoadBalancer = aws_lb.app.arn_suffix
        TargetGroup  = aws_lb_target_group.app.arn_suffix
      }
    }
  }

  alarm_actions = [aws_sns_topic.operations.arn]
  ok_actions    = [aws_sns_topic.operations.arn]
}

resource "aws_cloudwatch_metric_alarm" "alb_latency_p99" {
  alarm_name          = "${local.physical_name_prefix}-alb-latency-p99"
  alarm_description   = "Target response-time p99 exceeded the initial one-second threshold"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "TargetResponseTime"
  extended_statistic  = "p99"
  period              = 60
  evaluation_periods  = 3
  datapoints_to_alarm = 2
  threshold           = 1
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.app.arn_suffix
    TargetGroup  = aws_lb_target_group.app.arn_suffix
  }

  alarm_actions = [aws_sns_topic.operations.arn]
  ok_actions    = [aws_sns_topic.operations.arn]
}

resource "aws_cloudwatch_metric_alarm" "asg_in_service" {
  alarm_name          = "${local.physical_name_prefix}-asg-in-service-low"
  alarm_description   = "ASG has fewer than two in-service instances"
  namespace           = "AWS/AutoScaling"
  metric_name         = "GroupInServiceInstances"
  statistic           = "Minimum"
  period              = 60
  evaluation_periods  = 3
  datapoints_to_alarm = 2
  threshold           = 2
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "breaching"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app.name
  }

  alarm_actions = [aws_sns_topic.operations.arn]
  ok_actions    = [aws_sns_topic.operations.arn]
}

resource "aws_cloudwatch_metric_alarm" "app_memory" {
  alarm_name          = "${local.physical_name_prefix}-app-memory-high"
  alarm_description   = "Aggregate application memory utilization exceeded 80 percent"
  namespace           = "CWAgent"
  metric_name         = "mem_used_percent"
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 3
  datapoints_to_alarm = 2
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "missing"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app.name
  }

  alarm_actions = [aws_sns_topic.operations.arn]
  ok_actions    = [aws_sns_topic.operations.arn]
}

resource "aws_cloudwatch_metric_alarm" "app_disk" {
  alarm_name          = "${local.physical_name_prefix}-app-disk-high"
  alarm_description   = "Aggregate application root disk utilization exceeded 80 percent"
  namespace           = "CWAgent"
  metric_name         = "disk_used_percent"
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 3
  datapoints_to_alarm = 2
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "missing"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app.name
  }

  alarm_actions = [aws_sns_topic.operations.arn]
  ok_actions    = [aws_sns_topic.operations.arn]
}

resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "${local.physical_name_prefix}-rds-cpu-high"
  alarm_description   = "RDS CPU exceeded 80 percent"
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 5
  datapoints_to_alarm = 3
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "missing"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.app.identifier
  }

  alarm_actions = [aws_sns_topic.operations.arn]
  ok_actions    = [aws_sns_topic.operations.arn]
}

resource "aws_cloudwatch_metric_alarm" "rds_connections" {
  alarm_name          = "${local.physical_name_prefix}-rds-connections-high"
  alarm_description   = "RDS connections exceeded the initial lab threshold"
  namespace           = "AWS/RDS"
  metric_name         = "DatabaseConnections"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 3
  datapoints_to_alarm = 2
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "missing"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.app.identifier
  }

  alarm_actions = [aws_sns_topic.operations.arn]
  ok_actions    = [aws_sns_topic.operations.arn]
}

resource "aws_cloudwatch_metric_alarm" "rds_free_storage" {
  alarm_name          = "${local.physical_name_prefix}-rds-free-storage-low"
  alarm_description   = "RDS free storage is below 2 GiB"
  namespace           = "AWS/RDS"
  metric_name         = "FreeStorageSpace"
  statistic           = "Minimum"
  period              = 300
  evaluation_periods  = 3
  datapoints_to_alarm = 2
  threshold           = 2147483648
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "missing"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.app.identifier
  }

  alarm_actions = [aws_sns_topic.operations.arn]
  ok_actions    = [aws_sns_topic.operations.arn]
}

resource "aws_cloudwatch_dashboard" "operations" {
  dashboard_name = "${local.physical_name_prefix}-operations"

  dashboard_body = jsonencode({
    start          = "-PT8H"
    periodOverride = "inherit"
    widgets = [
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 2
        properties = {
          markdown = "# AWS Secure Observability Platform\nOperational health for the ${var.environment} environment. Initial alarm thresholds must be tuned from measured baselines."
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 2
        width  = 24
        height = 4
        properties = {
          title       = "Alarm status"
          region      = var.aws_region
          view        = "timeSeries"
          annotations = { alarms = local.alarm_arns }
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "ALB requests and target errors"
          region = var.aws_region
          period = 60
          stat   = "Sum"
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.app.arn_suffix, "TargetGroup", aws_lb_target_group.app.arn_suffix, { label = "Requests" }],
            [".", "HTTPCode_Target_5XX_Count", ".", ".", ".", ".", { label = "Target 5xx", yAxis = "right" }],
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "ALB target health and p99 latency"
          region = var.aws_region
          period = 60
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", "LoadBalancer", aws_lb.app.arn_suffix, "TargetGroup", aws_lb_target_group.app.arn_suffix, { stat = "Minimum", label = "Healthy" }],
            [".", "UnHealthyHostCount", ".", ".", ".", ".", { stat = "Maximum", label = "Unhealthy" }],
            [".", "TargetResponseTime", ".", ".", ".", ".", { stat = "p99", label = "Latency p99", yAxis = "right" }],
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6
        properties = {
          title  = "Application fleet"
          region = var.aws_region
          period = 60
          metrics = [
            ["AWS/AutoScaling", "GroupInServiceInstances", "AutoScalingGroupName", aws_autoscaling_group.app.name, { label = "In service" }],
            ["CWAgent", "cpu_usage_active", "AutoScalingGroupName", aws_autoscaling_group.app.name, { label = "CPU %", yAxis = "right" }],
            [".", "mem_used_percent", ".", ".", { label = "Memory %", yAxis = "right" }],
            [".", "disk_used_percent", ".", ".", { label = "Disk %", yAxis = "right" }],
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 12
        width  = 12
        height = 6
        properties = {
          title  = "RDS health"
          region = var.aws_region
          period = 60
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", aws_db_instance.app.identifier, { label = "CPU %" }],
            [".", "DatabaseConnections", ".", ".", { label = "Connections" }],
            [".", "FreeableMemory", ".", ".", { label = "Free memory", yAxis = "right" }],
            [".", "FreeStorageSpace", ".", ".", { label = "Free storage", yAxis = "right" }],
          ]
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 18
        width  = 24
        height = 6
        properties = {
          title  = "Recent application errors"
          region = var.aws_region
          view   = "table"
          query  = "SOURCE '${local.application_log_group_name}' | fields @timestamp, level, message, request_id, path, status_code | filter level = 'ERROR' or status_code >= 500 | sort @timestamp desc | limit 50"
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 24
        width  = 12
        height = 6
        properties = {
          title  = "Recent rejected network flows"
          region = var.aws_region
          view   = "table"
          query  = "SOURCE '${local.flow_log_group_name}' | fields @timestamp, @message | filter @message like / REJECT / | sort @timestamp desc | limit 50"
        }
      },
      {
        type   = "log"
        x      = 12
        y      = 24
        width  = 12
        height = 6
        properties = {
          title  = "Recent infrastructure changes"
          region = var.aws_region
          view   = "table"
          query  = "SOURCE '${local.cloudtrail_log_group_name}' | fields @timestamp, userIdentity.arn as actor, eventSource, eventName, sourceIPAddress, errorCode | filter eventName like /^(Create|Delete|Update|Modify|Put|Authorize|Revoke|Start|Stop)/ | sort @timestamp desc | limit 50"
        }
      },
    ]
  })
}
