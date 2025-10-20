resource "aws_s3_bucket" "s3_bucket" {
  bucket = "my-tf-bucket-${var.account_id}-for-static-website-hosting"

  tags = {
    Name = "My-bucket"
  }
}


resource "aws_s3_bucket_website_configuration" "site" {
  bucket = aws_s3_bucket.s3_bucket.id
  index_document { suffix = "index.html" }
  error_document { key    = "error.html" }
}


resource "aws_s3_bucket_ownership_controls" "enable_acls" {
  bucket = aws_s3_bucket.s3_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred" 
  }
}

resource "aws_s3_bucket_public_access_block" "site" {
  bucket                  = aws_s3_bucket.s3_bucket.id
  block_public_acls       = false
  ignore_public_acls      = false
  block_public_policy     = false
  restrict_public_buckets = false
}

locals { s3_origin_id = "myS3Origin" }

data "aws_iam_policy_document" "public_read" {
  statement {
    sid = "PublicReadGetObject"
    principals { 
    type = "AWS" 
    identifiers = ["*"] 
    }
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.s3_bucket.arn}/*"]
  }
}

resource "aws_s3_bucket_policy" "site_public" {
  bucket     = aws_s3_bucket.s3_bucket.id
  policy     = data.aws_iam_policy_document.public_read.json
  depends_on = [aws_s3_bucket_public_access_block.site]
}   