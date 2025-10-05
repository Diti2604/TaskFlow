resource "aws_cloudfront_distribution" "s3_distribution" {
 origin {
  domain_name = aws_s3_bucket_website_configuration.site.website_endpoint 
  origin_id   = local.s3_origin_id
  
  custom_origin_config {
    http_port              = 80
    https_port             = 443
    origin_protocol_policy = "http-only"
    origin_ssl_protocols   = ["TLSv1.2"]
  }
}
  enabled             = true
  default_root_object = "index.html"
  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    cache_policy_id  = data.aws_cloudfront_cache_policy.caching_disabled.id
    target_origin_id = local.s3_origin_id
    origin_request_policy_id   = data.aws_cloudfront_origin_request_policy.all_viewer_except_host.id
    compress                   = true
    viewer_protocol_policy = "allow-all"
  }
  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["US", "CA", "GB", "DE", "AL", "AT"]
    }
  }
  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
data "aws_cloudfront_cache_policy" "caching_disabled" {
  name = "Managed-CachingDisabled"
}
data "aws_cloudfront_origin_request_policy" "all_viewer_except_host" {
  name = "Managed-AllViewerExceptHostHeader"
}
