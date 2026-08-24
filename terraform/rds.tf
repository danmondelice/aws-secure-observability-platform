resource "aws_db_subnet_group" "app" {
  name        = "${local.physical_name_prefix}-db-subnets"
  subnet_ids  = [for az in local.availability_zones : aws_subnet.db[az].id]
  description = "Isolated database subnets across two Availability Zones"

  tags = {
    Name = "${local.name_prefix}-db-subnets"
  }
}

resource "aws_db_parameter_group" "app" {
  name        = "${local.physical_name_prefix}-mysql84"
  family      = "mysql8.4"
  description = "MySQL 8.4 logging parameters for the observability lab"

  parameter {
    name  = "general_log"
    value = var.enable_database_query_logging ? "1" : "0"
  }

  parameter {
    name  = "slow_query_log"
    value = "1"
  }

  parameter {
    name  = "long_query_time"
    value = "2"
  }

  parameter {
    name  = "log_output"
    value = "FILE"
  }

  tags = {
    Name = "${local.name_prefix}-mysql84"
  }
}

resource "aws_db_instance" "app" {
  identifier = "${local.physical_name_prefix}-mysql"

  engine         = "mysql"
  engine_version = var.database_engine_version
  instance_class = var.database_instance_class

  db_name  = var.database_name
  username = var.database_master_username
  port     = var.database_port

  manage_master_user_password   = true
  master_user_secret_kms_key_id = aws_kms_key.database.arn

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = aws_kms_key.database.arn

  multi_az               = var.database_multi_az
  publicly_accessible    = false
  network_type           = "IPV4"
  db_subnet_group_name   = aws_db_subnet_group.app.name
  vpc_security_group_ids = [aws_security_group.db.id]
  parameter_group_name   = aws_db_parameter_group.app.name

  iam_database_authentication_enabled = true
  enabled_cloudwatch_logs_exports     = ["error", "general", "slowquery"]

  backup_retention_period     = 7
  backup_window               = "03:00-04:00"
  maintenance_window          = "Sun:05:00-Sun:06:00"
  auto_minor_version_upgrade  = true
  allow_major_version_upgrade = false
  apply_immediately           = false

  deletion_protection       = var.database_deletion_protection
  skip_final_snapshot       = var.database_skip_final_snapshot
  final_snapshot_identifier = var.database_skip_final_snapshot ? null : "${local.physical_name_prefix}-mysql-final"
  copy_tags_to_snapshot     = true
  delete_automated_backups  = var.database_skip_final_snapshot

  tags = {
    Name = "${local.name_prefix}-mysql"
    Tier = "database"
  }

  lifecycle {
    precondition {
      condition = (
        var.environment != "prod" ||
        (var.database_deletion_protection && !var.database_skip_final_snapshot)
      )
      error_message = "Production requires database deletion protection and a final snapshot."
    }
  }

  depends_on = [aws_cloudwatch_log_group.rds]
}
