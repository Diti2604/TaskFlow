data "aws_lb" "test" {
  tags = {
    "kubernetes.io/ingress.name" = "fastapi-ingress"
    "alb.ingress.kubernetes.io/certificate-arn" = aws_acm_certificate.cert-base.arn
  }
}

resource "aws_api_gateway_vpc_link" "example" {
  name        = "example"
  description = "example description"
  target_arns = [data.aws_lb.test.arn]
}