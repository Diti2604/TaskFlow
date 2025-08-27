data "aws_lb" "ingress_alb" {
  tags = {
    "app"          = "fastapi"
    "ingress-name" = "fastapi-ingress"
  }
}

resource "aws_apigatewayv2_api" "http" {
  name          = "http-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_vpc_link" "link" {
  name          = "alb-vpc-link"
  subnet_ids = slice(aws_subnet.private-subnets[*].id, 0, var.private_subnets_count) 
  security_group_ids = [aws_vpc.my-vpc.default_security_group_id]
}

resource "aws_apigatewayv2_integration" "to_alb" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "HTTP_PROXY"
  connection_type        = "VPC_LINK"
  connection_id          = aws_apigatewayv2_vpc_link.link.id
  integration_method     = "ANY"
  integration_uri        = data.aws_lb.ingress_alb.arn
  payload_format_version = "1.0"
}