resource "aws_acm_certificate" "cert-base" {
  domain_name               = "${var.account_id}.realhandsonlabs.net"
  subject_alternative_names = ["login.${var.account_id}.realhandsonlabs.net", "db.${var.account_id}.realhandsonlabs.net", "extra.${var.account_id}.realhandsonlabs.net"]
  validation_method         = "DNS"
}

resource "aws_acm_certificate_validation" "name" {
  certificate_arn = aws_acm_certificate.cert-base.arn
  validation_record_fqdns = [for record in aws_route53_record.cert-validation : record.fqdn ]
}
