data "aws_lb" "test" {
  tags = {
      "name" = "k8s-default-fastapii-023c11cd46"
  }
}

# resource "aws_api_gateway_vpc_link" "example" {
#   name        = "example"
#   description = "example description"
#   target_arns = [data.aws_lb.test.arn]
# }


resource "aws_apigatewayv2_vpc_link" "example" {
  name          = "alb-vpc-link"
  subnet_ids = slice(aws_subnet.private-subnets[*].id, 0, var.private_subnets_count) 
  security_group_ids = [aws_vpc.my-vpc.default_security_group_id]
}