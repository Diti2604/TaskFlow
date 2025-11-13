data "aws_caller_identity" "root" {}

locals {
  account_id  = data.aws_caller_identity.root.account_id
  root_domain = "indritcloud.com"
  names       = [
    "taskflow.${local.root_domain}",
  ]
}

resource "aws_acm_certificate" "cert" {
  domain_name               = "indritcloud.com"
  provider                  = aws.us  # us-east-1 required for CloudFront (global service)
  subject_alternative_names = concat(local.names, ["api.taskflow.${local.root_domain}", "*.taskflow.${local.root_domain}"])
  validation_method         = "DNS"

  validation_option {
    domain_name       = "indritcloud.com"
    validation_domain = "indritcloud.com"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "cert" {
  provider                = aws.us
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert-validation : record.fqdn]

  timeouts {
    create = "10m"
  }
}

# Note: Since both CloudFront and ALB are in us-east-1, we can use the SAME certificate for both!
# CloudFront MUST use us-east-1 (global service requirement)
# ALB happens to also be in us-east-1, so one certificate covers both