resource "aws_kms_key" "database" {
  description             = "Encrypt RDS storage and its managed master-user secret"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  tags = {
    Name = "${local.name_prefix}-database-kms"
  }
}

resource "aws_kms_alias" "database" {
  name          = "alias/${local.physical_name_prefix}-database"
  target_key_id = aws_kms_key.database.key_id
}
