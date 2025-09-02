data "aws_lb" "ingress_alb" {
  tags = {
    "app"                          = "fastapi"
    "elbv2.k8s.aws/cluster"        = "cluster1"
    "ingress-name"                 = "fastapi-ingress"
    "ingress.k8s.aws/stack"        = "default/fastapi-ingress"
    "ingress.k8s.aws/resource"   = "LoadBalancer" 
  }
  depends_on = [ kubernetes_ingress_v1.fastapi , helm_release.aws_lb_controller]
  timeouts {
    read = "15m"
  }
}

data "aws_lb_listener" "http" {
  depends_on = [ data.aws_lb.ingress_alb ]
  load_balancer_arn = data.aws_lb.ingress_alb.arn
  port              = 80
  timeouts {
    read = "15m"
  }
}

resource "aws_apigatewayv2_api" "http" {
  name          = "http-api"
  protocol_type = "HTTP"
  depends_on = [ data.aws_lb_listener.http ]
}

resource "aws_apigatewayv2_integration" "api-gateway-integration" {
  depends_on = [ data.aws_lb_listener.http ]
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "HTTP_PROXY"
  connection_type        = "VPC_LINK"
  connection_id          = aws_apigatewayv2_vpc_link.link.id
  integration_method     = "ANY"
  integration_uri        = data.aws_lb_listener.http.arn
  payload_format_version = "1.0"
}

resource "aws_apigatewayv2_route" "root" {
  depends_on = [ data.aws_lb_listener.http ]
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "GET /"
  target    = "integrations/${aws_apigatewayv2_integration.api-gateway-integration.id}"
}

resource "aws_apigatewayv2_route" "users_post" {
  depends_on = [ data.aws_lb_listener.http ]
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "POST /users"
  target    = "integrations/${aws_apigatewayv2_integration.api-gateway-integration.id}"
}

resource "aws_apigatewayv2_route" "login_post" {
  depends_on = [ data.aws_lb_listener.http ]
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "POST /login"
  target    = "integrations/${aws_apigatewayv2_integration.api-gateway-integration.id}"
}


resource "aws_apigatewayv2_stage" "default-stage" {
  depends_on = [ data.aws_lb_listener.http ]
  api_id      = aws_apigatewayv2_api.http.id
  name        = "$default"
  auto_deploy = true
}   

