resource "time_sleep" "post_alb_buffer" {
  depends_on      = [kubernetes_ingress_v1.fastapi]
  create_duration = "9m"
}

data "aws_lb" "ingress_alb" {
  tags = {
    "elbv2.k8s.aws/cluster" = var.cluster_name
    "ingress-name"          = "fastapi-ingress"
  }
  timeouts { read =  "15m" }
  depends_on = [time_sleep.post_alb_buffer]
}

data "aws_lb_listener" "http" {
  load_balancer_arn = data.aws_lb.ingress_alb.arn
  port              = 80
  timeouts { read = "15m" }
  depends_on = [data.aws_lb.ingress_alb]
}

resource "aws_apigatewayv2_api" "http" {
  name          = "http-api"
  protocol_type = "HTTP"
  depends_on    = [time_sleep.post_alb_buffer]
}

resource "aws_apigatewayv2_integration" "api-gateway-integration" {
  depends_on = [time_sleep.post_alb_buffer]
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "HTTP_PROXY"
  connection_type        = "VPC_LINK"
  connection_id          = aws_apigatewayv2_vpc_link.alb_link.id
  integration_method     = "ANY"
  integration_uri        = data.aws_lb_listener.http.arn
  payload_format_version = "1.0"
}

resource "aws_apigatewayv2_route" "root" {
  depends_on = [time_sleep.post_alb_buffer]
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "GET /"
  target    = "integrations/${aws_apigatewayv2_integration.api-gateway-integration.id}"
}

resource "aws_apigatewayv2_route" "users_post" {
  depends_on =[time_sleep.post_alb_buffer]
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "POST /users"
  target    = "integrations/${aws_apigatewayv2_integration.api-gateway-integration.id}"
}

resource "aws_apigatewayv2_route" "login_post" {
  depends_on = [time_sleep.post_alb_buffer]
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "POST /login"
  target    = "integrations/${aws_apigatewayv2_integration.api-gateway-integration.id}"
}


resource "aws_apigatewayv2_stage" "default-stage" {
  depends_on = [time_sleep.post_alb_buffer]
  api_id      = aws_apigatewayv2_api.http.id
  name        = "$default"
  auto_deploy = true
}   

