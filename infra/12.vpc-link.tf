resource "aws_apigatewayv2_vpc_link" "alb_link" {
  name               = "alb-vpc-link"
  subnet_ids         = slice(aws_subnet.private-subnets[*].id, 0, var.private_subnets_count)
  security_group_ids = [aws_security_group.apigw_vpclink_sg.id]
}

resource "aws_security_group" "apigw_vpclink_sg" {
  vpc_id = aws_vpc.my-vpc.id
  name   = "apigw-vpclink-sg"
  description = "Security group for API Gateway VPC Link"
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.my-vpc.cidr_block]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = var.vpc_private_cidr_blocks
}
  tags = {
    Name = "apigw_vpclink_sg"
  }
}