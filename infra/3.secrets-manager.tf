# resource "aws_kms_key" "secrets-manager-password" {
#   description         = "KMS Key for the RDS password"
#   enable_key_rotation = true
#   key_usage           = "ENCRYPT_DECRYPT"
#   multi_region        = true
# }
