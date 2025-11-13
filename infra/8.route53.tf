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

# TEMPORARILY COMMENTED OUT: The ALB is created asynchronously by the AWS Load Balancer Controller.
# Even with a 5-minute wait, it may not be ready. Uncomment after cluster is fully up, or use external-dns.
# resource "time_sleep" "wait_for_alb" {
#   depends_on = [kubernetes_ingress_v1.fastapi, helm_release.aws_lb_controller]
#   create_duration = "300s"
# }
#
# data "aws_lb" "fastapi_alb" {
#   depends_on = [time_sleep.wait_for_alb]
#   tags = { ingress-name = "fastapi-ingress" }
# }
#
# # Create a Route53 alias record for the API that points to the ALB
# resource "aws_route53_record" "api" {
#   zone_id = data.aws_route53_zone.main.zone_id
#   name    = "api.taskflow.indritcloud.com"
#   type    = "A"
#   allow_overwrite = true
#
#   alias {
#     name                   = data.aws_lb.fastapi_alb.dns_name
#     zone_id                = data.aws_lb.fastapi_alb.zone_id
#     evaluate_target_health = false
#   }
# }

# NOTE: To automatically create the API DNS record, install external-dns and annotate your ingress:
#   metadata:
#     annotations:
#       external-dns.alpha.kubernetes.io/hostname: "api.taskflow.indritcloud.com"

