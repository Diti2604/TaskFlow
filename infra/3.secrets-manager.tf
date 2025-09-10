data "aws_secretsmanager_secret" "rds_master" {
  depends_on = [ aws_db_instance.database-1 ]
  arn = aws_db_instance.database-1.master_user_secret[0].secret_arn
}
resource "aws_kms_key" "secrets-manager-password" {
  description         = "KMS Key for the RDS password"
  enable_key_rotation = true
  key_usage           = "ENCRYPT_DECRYPT"
  multi_region        = true
}