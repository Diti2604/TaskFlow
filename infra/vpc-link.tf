resource "aws_api_gateway_vpc_link" "vpc-link" {
  name        = "internal-alb-vpc-link"
  description = "The VPC Link to connect the internal ALB to the API Gateway"
  target_arns = [helm_release.aws_lb_controller.id]
}