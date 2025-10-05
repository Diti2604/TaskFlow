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

resource "aws_acm_certificate" "imported" {
  certificate_body = tls_self_signed_cert.this.cert_pem
  private_key      = tls_private_key.this.private_key_pem

  tags = {
    Project = "fastapi"
    Env     = local.account_id
    Role    = "ingress-cert"
  }
}

output "acm_arn" {
  value = aws_acm_certificate.imported.arn
}