resource "aws_api_gateway_vpc_link" "example" {
  name        = "example"
  description = "example description"
  target_arns = [kubernetes_service_account.alb_controller.metadata[0].name]
}