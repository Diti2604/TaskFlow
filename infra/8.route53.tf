data "aws_route53_zone" "main" {
  name         = "${var.account_id}.realhandsonlabs.net"
  private_zone = false
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


