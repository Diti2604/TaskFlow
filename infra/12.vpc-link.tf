resource "aws_apigatewayv2_api" "example" {
  name          = "http-api"
  protocol_type = "HTTP"
}