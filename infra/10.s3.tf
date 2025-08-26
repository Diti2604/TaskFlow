# resource "aws_s3_bucket" "s3_bucket" {
#   bucket = "my-tf-bucket-${var.account_id}"

#   tags = {
#     Name = "My-bucket"
#   }
# }


# resource "aws_s3_bucket_website_configuration" "site" {
#   bucket = aws_s3_bucket.s3_bucket.id
#   index_document { suffix = "index.html" }
#   error_document { key    = "error.html" }
# }

# resource "aws_s3_bucket_policy" "site_public" {
#   bucket = aws_s3_bucket.s3_bucket.id
#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [{
#       Effect    = "Allow",
#       Principal = "*",
#       Action    = ["s3:GetObject"],
#       Resource  = "${aws_s3_bucket.s3_bucket.arn}/*"
#     }]
#   })
# }


# resource "aws_s3_bucket_public_access_block" "site" {
#   bucket                  = aws_s3_bucket.s3_bucket.id
#   block_public_acls       = false
#   ignore_public_acls      = false
#   block_public_policy     = false
#   restrict_public_buckets = false
# }