locals {
  account_id = data.aws_caller_identity.current.account_id
  root_domain = "${local.account_id}.realhandsonlabs.net"
  sans = [
    "login.${local.root_domain}",
    "db.${local.root_domain}",
    "extra.${local.root_domain}",
  ]
}

resource "tls_private_key" "this" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "this" {
  private_key_pem = tls_private_key.this.private_key_pem
  subject {
    common_name  = local.root_domain
    organization = "HandsOnLabs"
  }
  validity_period_hours = 24 * 365
  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
  dns_names = concat([local.root_domain], local.sans)
}

# resource "aws_acm_certificate" "imported" {
#   certificate_body = tls_self_signed_cert.this.cert_pem
#   private_key      = tls_private_key.this.private_key_pem

#   tags = {
#     Project = "fastapi"
#     Env     = local.account_id
#     Role    = "ingress-cert"
#   }
# }

# output "acm_arn" {
#   value = aws_acm_certificate.imported.arn
# }


#############################
# Route 53 Zone lookup
#############################
# Looks up the hosted zone for "<account_id>.realhandsonlabs.net."
data "aws_route53_zone" "root" {
  name         = local.root_domain
  private_zone = false
}

#############################
# Public ACM certificate (DNS validation)
#############################
resource "aws_acm_certificate" "cf" {
  domain_name               = local.root_domain
  subject_alternative_names = local.sans
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Project = "fastapi"
    Env     = local.account_id
    Role    = "ingress-cert"
  }
}

# Create DNS CNAMEs for *each* domain validation option
resource "aws_route53_record" "acm_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cf.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id = data.aws_route53_zone.root.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.record]
}

# Tell ACM to validate using the DNS records above
resource "aws_acm_certificate_validation" "cf" {
  provider = aws.us_east_1
  certificate_arn         = aws_acm_certificate.cf.arn
  validation_record_fqdns = [for r in aws_route53_record.acm_validation : r.fqdn]
}
