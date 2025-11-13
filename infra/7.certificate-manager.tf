data "aws_caller_identity" "root" {}

locals {
  account_id  = data.aws_caller_identity.root.account_id
  root_domain = "indritcloud.com"
  names       = [
    "taskflow.${local.root_domain}",
  ]
}

resource "aws_acm_certificate" "cert" {
  domain_name       = "indritcloud.com"
  provider                = aws.us
  subject_alternative_names = local.names
  validation_method = "DNS"

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