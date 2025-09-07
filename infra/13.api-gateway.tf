
data "aws_lb" "ingress_alb" {
  tags = {
    "elbv2.k8s.aws/cluster" = var.cluster_name
    "ingress-name"          = "fastapi-ingress"
  }
  timeouts { read = "15m" }
  depends_on = [data.aws_resourcegroupstaggingapi_resources.ingress_alb]
}

data "aws_lb_listener" "http" {
  load_balancer_arn = data.aws_lb.ingress_alb.arn
  port              = 80
  timeouts { read = "15m" }
  depends_on = [data.aws_lb.ingress_alb]
}


resource "null_resource" "alb_ready_gate" {
  triggers = {
    alb_arn      = data.aws_lb.ingress_alb.arn
    listener_arn = data.aws_lb_listener.http.arn
  }

provisioner "local-exec" {
  command = <<-EOT
    set -e
    echo "Waiting for ALB to be available..."
    aws elbv2 wait load-balancer-available --load-balancer-arns ${data.aws_lb.ingress_alb.arn} --region ${var.aws_region}
    
    echo "Checking target group health..."
    TG_ARN=$(aws elbv2 describe-listeners --listener-arn ${data.aws_lb_listener.http.arn} --region ${var.aws_region} \
      --query 'Listeners[0].DefaultActions[0].TargetGroupArn' --output text)
    
    start_time=$(date +%s)
    while true; do
      healthy=$(aws elbv2 describe-target-health --target-group-arn $TG_ARN --region ${var.aws_region} \
        --query 'TargetHealthDescriptions[?TargetHealth.State==`healthy`]' --output json | jq length)
      if [ "$healthy" -ge 1 ]; then
        echo "At least one target is healthy."
        break
      fi
      now=$(date +%s)
      elapsed=$((now - start_time))
      if [ "$elapsed" -ge ${var.max_wait_seconds} ]; then
        echo "Timeout waiting for healthy targets."
        exit 1
      fi
      echo "Waiting for healthy targets... ($elapsed/${var.max_wait_seconds}s)"
      sleep 10
    done
  EOT
  interpreter = ["bash", "-c"]
}
}

resource "aws_apigatewayv2_api" "http" {
  name          = "http-api"
  protocol_type = "HTTP"
  depends_on    = [null_resource.alb_ready_gate]
}

resource "aws_apigatewayv2_integration" "api-gateway-integration" {
  depends_on = [null_resource.alb_ready_gate]
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "HTTP_PROXY"
  connection_type        = "VPC_LINK"
  connection_id          = aws_apigatewayv2_vpc_link.alb_link.id
  integration_method     = "ANY"
  integration_uri        = data.aws_lb_listener.http.arn
  payload_format_version = "1.0"
}

resource "aws_apigatewayv2_route" "root" {
  depends_on = [null_resource.alb_ready_gate]
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "GET /"
  target    = "integrations/${aws_apigatewayv2_integration.api-gateway-integration.id}"
}

resource "aws_apigatewayv2_route" "users_post" {
  depends_on = [null_resource.alb_ready_gate]
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "POST /users"
  target    = "integrations/${aws_apigatewayv2_integration.api-gateway-integration.id}"
}

resource "aws_apigatewayv2_route" "login_post" {
  depends_on = [null_resource.alb_ready_gate]
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "POST /login"
  target    = "integrations/${aws_apigatewayv2_integration.api-gateway-integration.id}"
}


resource "aws_apigatewayv2_stage" "default-stage" {
  depends_on = [null_resource.alb_ready_gate]
  api_id      = aws_apigatewayv2_api.http.id
  name        = "$default"
  auto_deploy = true
}   

