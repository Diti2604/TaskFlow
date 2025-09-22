module "s3_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"

  bucket = "my-s3-bucket-${var.account_id}"
  acl    = "private"

  control_object_ownership = true
  object_ownership         = "ObjectWriter"

  versioning = {
    enabled = true
  }
}

variable "account_id" {
  type        = string
  description = "Account ID of new playgrounds"
  default     = "608283508317"
}

output "s3-bucket-name" {
  value = "my-s3-bucket-${var.account_id}"
}
