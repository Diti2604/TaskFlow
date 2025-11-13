data "aws_route53_zone" "main" {
  name         = "indritcloud.com"
  private_zone = false
}


resource "aws_route53_record" "cert-validation" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id = data.aws_route53_zone.main.zone_id
}

resource "aws_route53_record" "cloudmeter" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "taskflow.indritcloud.com"
  type    = "A"
  allow_overwrite = true

  alias {
    name                   = aws_cloudfront_distribution.s3_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}

# Lookup the ALB created by the AWS Load Balancer Controller for the Kubernetes ingress
data "aws_lb" "fastapi_alb" {
  # find by tag set in ingress annotations: "ingress-name=fastapi-ingress"
  # Some provider versions expect a tags map rather than filter blocks.
  tags = {
    ingress-name = "fastapi-ingress"
  }
}

# Create a Route53 alias record for the API that points to the ALB
resource "aws_route53_record" "api" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "api.taskflow.indritcloud.com"
  type    = "A"
  allow_overwrite = true

  alias {
    name                   = data.aws_lb.fastapi_alb.dns_name
    zone_id                = data.aws_lb.fastapi_alb.zone_id
    evaluate_target_health = false
  }

  # If the ALB is not yet present when terraform runs, this resource may fail.
  # In CI you may need to ensure the cluster/ingress is created before this record is applied.
}

