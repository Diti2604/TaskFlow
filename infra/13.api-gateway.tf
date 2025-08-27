data "aws_lb" "ingress_alb" {
  tags = {
    "app"                          = "fastapi"
    "elbv2.k8s.aws/cluster"        = "cluster1"
    "ingress-name"                 = "fastapi-ingress"
    "ingress.k8s.aws/stack"        = "default/fastapi-ingress"
    "ingress.k8s.aws/resource"   = "LoadBalancer" 
  }
}

data "aws_lb_listener" "https" {
  load_balancer_arn = data.aws_lb.ingress_alb.arn
  port              = 443
}

resource "aws_apigatewayv2_api" "http" {
  name          = "http-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "api-gateway-integration" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "HTTP_PROXY"
  connection_type        = "VPC_LINK"
  connection_id          = aws_apigatewayv2_vpc_link.link.id
  integration_method     = "ANY"
  integration_uri        = data.aws_lb_listener.https.arn
  payload_format_version = "1.0"
}

resource "aws_apigatewayv2_route" "root_any" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "ANY /"
  target    = "integrations/${aws_apigatewayv2_integration.api-gateway-integration.id}"
}

resource "aws_apigatewayv2_route" "health_get" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "ANY /users"
  target    = "integrations/${aws_apigatewayv2_integration.api-gateway-integration.id}"
}

resource "aws_apigatewayv2_route" "proxy_any" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "ANY /login"
  target    = "integrations/${aws_apigatewayv2_integration.api-gateway-integration.id}"
}


resource "aws_apigatewayv2_stage" "prod" {
  api_id      = aws_apigatewayv2_api.http.id
  name        = "prod"
  auto_deploy = true
}

