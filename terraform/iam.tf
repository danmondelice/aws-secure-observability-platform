data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    sid     = "EC2AssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "app" {
  name               = "${local.name_prefix}-ec2-role"
  description        = "Runtime role for private application instances"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = {
    Name = "${local.name_prefix}-ec2-role"
  }
}

resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "app" {
  name = "${local.name_prefix}-ec2-profile"
  role = aws_iam_role.app.name
}

data "aws_iam_policy_document" "app_database_secret" {
  statement {
    sid    = "ReadOnlyApplicationDatabaseSecret"
    effect = "Allow"
    actions = [
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetSecretValue",
    ]
    resources = [aws_db_instance.app.master_user_secret[0].secret_arn]
  }

  statement {
    sid       = "DecryptApplicationDatabaseSecret"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = [aws_kms_key.database.arn]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["secretsmanager.${var.aws_region}.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "kms:EncryptionContext:SecretARN"
      values   = [aws_db_instance.app.master_user_secret[0].secret_arn]
    }
  }
}

resource "aws_iam_role_policy" "app_database_secret" {
  name   = "read-application-database-secret"
  role   = aws_iam_role.app.id
  policy = data.aws_iam_policy_document.app_database_secret.json
}

data "aws_iam_policy_document" "cloudwatch_agent" {
  statement {
    sid    = "WriteProjectLogStreams"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
    ]
    resources = flatten([
      for log_group in [
        aws_cloudwatch_log_group.application,
        aws_cloudwatch_log_group.bootstrap,
        aws_cloudwatch_log_group.system,
      ] : [log_group.arn, "${log_group.arn}:log-stream:*"]
    ])
  }

  statement {
    sid       = "PublishCloudWatchAgentMetrics"
    effect    = "Allow"
    actions   = ["cloudwatch:PutMetricData"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "cloudwatch:namespace"
      values   = ["CWAgent"]
    }
  }
}

resource "aws_iam_role_policy" "cloudwatch_agent" {
  name   = "publish-project-telemetry"
  role   = aws_iam_role.app.id
  policy = data.aws_iam_policy_document.cloudwatch_agent.json
}
