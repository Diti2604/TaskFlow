output "test" {
  value = var.db_subnet_group_name
}

output "alb_arn" {
  description = "ARN of the discovered ALB"
  value       = data.aws_lb.ingress_alb.arn
}

output "alb_dns" {
  description = "DNS name of the discovered ALB"
  value       = data.aws_lb.ingress_alb.dns_name
}

output "listener_arn" {
  description = "ARN of the ALB HTTP listener"
  value       = data.aws_lb_listener.http.arn
}

output "http_api_endpoint" {
  description = "API Gateway HTTP API endpoint"
  value       = aws_apigatewayv2_api.http.api_endpoint
}