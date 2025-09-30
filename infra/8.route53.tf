data "aws_route53_zone" "main" {
  name         = "${var.account_id}.realhandsonlabs.net"
  private_zone = false
}

resource "aws_route53_record" "cert-validation" {

  for_each = {
    for dvo in aws_acm_certificate.cert-base.domain_validation_options : dvo.domain_name => {
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
resource "aws_route53_record" "database" {
  zone_id = data.aws_route53_zone.main.zone_id
  name = "db.${var.account_id}.realhandsonlabs.net"
  type = "CNAME"
  ttl = "300"
  records = ["${aws_db_instance.database-1.address}"]
}
resource "aws_route53_record" "login" {
  zone_id = data.aws_route53_zone.main.zone_id
  name     = "login.${var.account_id}.realhandsonlabs.net"
  type     = "CNAME" 
  ttl      = 300
  records  = ["${aws_cloudfront_distribution.s3_distribution.domain_name}"] 
}


