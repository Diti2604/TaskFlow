locals {
  account_id  = data.aws_caller_identity.current.account_id
  root_domain = "${local.account_id}.realhandsonlabs.net"
  names       = [
    "login.${local.root_domain}",
    "db.${local.root_domain}",
    "extra.${local.root_domain}",
  ]
}

# 1) ACME account key
# ACME account key
resource "tls_private_key" "acme_account" {
  algorithm = "RSA"
  rsa_bits  = 2048
}


# 2) Certificate key (this must match the cert you import to ACM)
resource "tls_private_key" "cert_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "acme_registration" "this" {
  account_key_pem         = tls_private_key.acme_account.private_key_pem
  email_address           = "email@gmail.com"
}

resource "acme_certificate" "le" {
  account_key_pem           = acme_registration.this.account_key_pem
  common_name               = local.root_domain
  subject_alternative_names = local.names

  dns_challenge { provider = "route53" } 
}

resource "aws_acm_certificate" "imported" {
  private_key       = acme_certificate.le.private_key_pem
  certificate_body  = acme_certificate.le.certificate_pem
  certificate_chain = acme_certificate.le.issuer_pem

  tags = { Project = "fastapi", Env = "playground", Role = "cloudfront-cert" }
}


output "acm_arn" {
  value = aws_acm_certificate.imported.arn
}