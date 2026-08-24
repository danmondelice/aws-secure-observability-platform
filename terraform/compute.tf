data "aws_ssm_parameter" "al2023_arm64_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}

resource "aws_launch_template" "app" {
  name_prefix            = "${local.physical_name_prefix}-app-"
  description            = "Hardened launch template for the private application tier"
  image_id               = data.aws_ssm_parameter.al2023_arm64_ami.value
  instance_type          = var.instance_type
  update_default_version = true

  iam_instance_profile {
    arn = aws_iam_instance_profile.app.arn
  }

  vpc_security_group_ids = [aws_security_group.app.id]

  metadata_options {
    http_endpoint               = "enabled"
    http_protocol_ipv6          = "disabled"
    http_put_response_hop_limit = 1
    http_tokens                 = "required"
    instance_metadata_tags      = "disabled"
  }

  monitoring {
    enabled = true
  }

  credit_specification {
    cpu_credits = "standard"
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      delete_on_termination = true
      encrypted             = true
      volume_size           = 10
      volume_type           = "gp3"
    }
  }

  user_data = base64encode(templatefile("${path.module}/templates/user_data.sh.tftpl", {
    app_port            = var.app_port
    application_git_ref = var.application_git_ref
    aws_region          = var.aws_region
    database_host       = aws_db_instance.app.address
    database_name       = var.database_name
    database_port       = var.database_port
    database_secret_arn = aws_db_instance.app.master_user_secret[0].secret_arn
  }))

  tag_specifications {
    resource_type = "instance"

    tags = merge(local.common_tags, {
      Name = "${local.name_prefix}-app"
      Role = "application"
    })
  }

  tag_specifications {
    resource_type = "volume"

    tags = merge(local.common_tags, {
      Name = "${local.name_prefix}-app-root"
      Role = "application"
    })
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_iam_role_policy.app_database_secret,
    aws_iam_role_policy_attachment.ssm_managed_instance_core,
  ]
}

resource "aws_autoscaling_group" "app" {
  name                      = "${local.name_prefix}-asg"
  min_size                  = var.asg_min_size
  desired_capacity          = var.asg_desired_capacity
  max_size                  = var.asg_max_size
  health_check_type         = "ELB"
  health_check_grace_period = 300
  default_instance_warmup   = 180
  vpc_zone_identifier       = [for az in local.availability_zones : aws_subnet.app[az].id]
  target_group_arns         = [aws_lb_target_group.app.arn]
  termination_policies      = ["OldestLaunchTemplate", "Default"]
  capacity_rebalance        = false
  enabled_metrics = [
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupMaxSize",
    "GroupMinSize",
    "GroupPendingInstances",
    "GroupStandbyInstances",
    "GroupTerminatingInstances",
    "GroupTotalInstances",
  ]

  launch_template {
    id      = aws_launch_template.app.id
    version = tostring(aws_launch_template.app.latest_version)
  }

  instance_refresh {
    strategy = "Rolling"

    preferences {
      auto_rollback          = true
      instance_warmup        = 180
      min_healthy_percentage = 100
      max_healthy_percentage = 150
      skip_matching          = true
    }
  }

  dynamic "tag" {
    for_each = merge(local.common_tags, {
      Name = "${local.name_prefix}-app"
      Role = "application"
    })

    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    precondition {
      condition = (
        var.asg_min_size >= 2 &&
        var.asg_desired_capacity >= var.asg_min_size &&
        var.asg_max_size >= var.asg_desired_capacity
      )
      error_message = "ASG capacity must satisfy: minimum >= 2, desired >= minimum, and maximum >= desired."
    }
  }
}

resource "aws_autoscaling_policy" "cpu_target" {
  name                   = "${local.name_prefix}-cpu-50"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 50
  }
}
