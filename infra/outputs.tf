output "test" {
  value = var.db_subnet_group_name
}

output "site_bucket_name" {
  description = "S3 bucket that holds the frontend static site"
  value       = aws_s3_bucket.site.bucket
}

output "cloudfront_domain" {
  description = "CloudFront distribution domain name for the site"
  value       = aws_cloudfront_distribution.s3_distribution.domain_name
  depends_on  = [aws_cloudfront_distribution.s3_distribution]
}

output "rds_endpoint" {
  description = "RDS instance endpoint address"
  value       = aws_db_instance.database-1.address
  depends_on  = [aws_db_instance.database-1]
}

output "rds_secret_arn" {
  description = "ARN of the Secrets Manager secret holding DB credentials"
  value       = aws_db_instance.database-1.master_user_secret[0].secret_arn
  depends_on  = [aws_db_instance.database-1]
}

