data "aws_lb" "test" {
  tags = {
      "kubernetes.io/ingress.class"            = "alb"
      "alb.ingress.kubernetes.io/scheme"        = "internal"
      "alb.ingress.kubernetes.io/listen-ports"  = "[{\"HTTP\":80},{\"HTTPS\":443}]"
      "alb.ingress.kubernetes.io/certificate-arn" = aws_acm_certificate.cert-base.arn
      "alb.ingress.kubernetes.io/target-type"   = "ip"
  }
}

resource "aws_api_gateway_vpc_link" "example" {
  name        = "example"
  description = "example description"
  target_arns = [data.aws_lb.test.arn]
}