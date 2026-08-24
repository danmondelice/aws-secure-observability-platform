data "aws_iam_policy_document" "config_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:${data.aws_partition.current.partition}:config:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"]
    }
  }
}

resource "aws_iam_role" "config" {
  name               = "${local.physical_name_prefix}-aws-config"
  assume_role_policy = data.aws_iam_policy_document.config_assume_role.json
}

resource "aws_iam_role_policy_attachment" "config" {
  role       = aws_iam_role.config.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_config_configuration_recorder" "main" {
  name     = "${local.physical_name_prefix}-recorder"
  role_arn = aws_iam_role.config.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true

    recording_strategy {
      use_only = "ALL_SUPPORTED_RESOURCE_TYPES"
    }
  }

  recording_mode {
    recording_frequency = "CONTINUOUS"
  }
}

resource "aws_config_delivery_channel" "main" {
  name           = "${local.physical_name_prefix}-delivery"
  s3_bucket_name = aws_s3_bucket.audit.id
  s3_kms_key_arn = aws_kms_key.audit.arn

  snapshot_delivery_properties {
    delivery_frequency = "Six_Hours"
  }

  depends_on = [aws_s3_bucket_policy.audit]
}

resource "aws_config_configuration_recorder_status" "main" {
  name       = aws_config_configuration_recorder.main.name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.main]
}

locals {
  config_managed_rules = {
    restricted_ssh = {
      name       = "restricted-ssh"
      identifier = "INCOMING_SSH_DISABLED"
    }
    encrypted_volumes = {
      name       = "encrypted-volumes"
      identifier = "ENCRYPTED_VOLUMES"
    }
    rds_private = {
      name       = "rds-instance-public-access-check"
      identifier = "RDS_INSTANCE_PUBLIC_ACCESS_CHECK"
    }
    rds_encrypted = {
      name       = "rds-storage-encrypted"
      identifier = "RDS_STORAGE_ENCRYPTED"
    }
    cloudtrail_enabled = {
      name       = "cloudtrail-enabled"
      identifier = "CLOUD_TRAIL_ENABLED"
    }
    vpc_flow_logs = {
      name       = "vpc-flow-logs-enabled"
      identifier = "VPC_FLOW_LOGS_ENABLED"
    }
    alb_waf = {
      name       = "alb-waf-enabled"
      identifier = "ALB_WAF_ENABLED"
    }
  }
}

resource "aws_config_config_rule" "managed" {
  for_each = local.config_managed_rules

  name        = "${local.physical_name_prefix}-${each.value.name}"
  description = "AWS managed Config evaluation for ${each.value.name}"

  source {
    owner             = "AWS"
    source_identifier = each.value.identifier
  }

  depends_on = [aws_config_configuration_recorder_status.main]
}
