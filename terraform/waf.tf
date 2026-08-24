resource "aws_cloudwatch_log_group" "waf" {
  name              = local.waf_log_group_name
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.observability.arn
}

resource "aws_wafv2_web_acl" "app" {
  name        = "${local.physical_name_prefix}-web-acl"
  description = "Regional protection for the public application load balancer"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedRulesSQLiRuleSet"
    priority = 10

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesSQLiRuleSet"
      sampled_requests_enabled   = false
    }
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 20

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesCommonRuleSet"
      sampled_requests_enabled   = false
    }
  }

  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 30

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesKnownBadInputsRuleSet"
      sampled_requests_enabled   = false
    }
  }

  rule {
    name     = "RateLimitPerSourceIp"
    priority = 40

    action {
      block {}
    }

    statement {
      rate_based_statement {
        aggregate_key_type    = "IP"
        evaluation_window_sec = 60
        limit                 = var.waf_rate_limit
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitPerSourceIp"
      sampled_requests_enabled   = false
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${local.physical_name_prefix}-web-acl"
    sampled_requests_enabled   = false
  }

  tags = {
    Name = "${local.name_prefix}-web-acl"
  }
}

resource "aws_wafv2_web_acl_association" "app" {
  resource_arn = aws_lb.app.arn
  web_acl_arn  = aws_wafv2_web_acl.app.arn
}

resource "aws_wafv2_web_acl_logging_configuration" "app" {
  resource_arn            = aws_wafv2_web_acl.app.arn
  log_destination_configs = [aws_cloudwatch_log_group.waf.arn]

  redacted_fields {
    single_header {
      name = "authorization"
    }
  }

  redacted_fields {
    query_string {}
  }

  logging_filter {
    default_behavior = "DROP"

    filter {
      behavior    = "KEEP"
      requirement = "MEETS_ANY"

      condition {
        action_condition {
          action = "BLOCK"
        }
      }
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "waf_blocked_requests" {
  alarm_name          = "${local.physical_name_prefix}-waf-blocked-requests"
  alarm_description   = "AWS WAF blocked one or more requests; review the terminating rule and source."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  threshold           = 1
  metric_name         = "BlockedRequests"
  namespace           = "AWS/WAFV2"
  period              = 60
  statistic           = "Sum"
  treat_missing_data  = "notBreaching"

  dimensions = {
    WebACL = aws_wafv2_web_acl.app.name
    Region = var.aws_region
    Rule   = "ALL"
  }

  alarm_actions = [aws_sns_topic.operations.arn]
  ok_actions    = [aws_sns_topic.operations.arn]
}
