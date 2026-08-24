resource "aws_securityhub_account" "cspm" {
  enable_default_standards  = false
  control_finding_generator = "SECURITY_CONTROL"

  depends_on = [aws_config_configuration_recorder_status.main]
}

resource "aws_securityhub_standards_subscription" "foundational" {
  standards_arn = "arn:${data.aws_partition.current.partition}:securityhub:${var.aws_region}::standards/aws-foundational-security-best-practices/v/1.0.0"

  depends_on = [aws_securityhub_account.cspm]
}

resource "aws_securityhub_account_v2" "main" {
  tags = {
    Name = "${local.name_prefix}-security-hub"
  }

  depends_on = [
    aws_guardduty_detector.main,
    aws_securityhub_account.cspm,
  ]
}
