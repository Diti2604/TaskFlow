data "aws_lb" "test" {
  tags = {
      "name" = "k8s-default-fastapii-023c11cd46"
  }
}

resource "aws_api_gateway_vpc_link" "example" {
  name        = "example"
  description = "example description"
  target_arns = [data.aws_lb.test.arn]
}