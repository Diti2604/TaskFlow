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

output "alb_endpoint" {
  description = "ALB endpoint for FastAPI backend (use this for frontend VITE_API_BASE)"
  value       = "Retrieve via: kubectl get ingress fastapi-ingress -n default -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
}

output "public_subnet_ids" {
  description = "Public subnet IDs (for internet-facing ALB)"
  value       = aws_subnet.public-subnets[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs (for EKS nodes and RDS)"
  value       = aws_subnet.private-subnets[*].id
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.site_distribution.id
}
