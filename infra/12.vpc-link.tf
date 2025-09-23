resource "aws_apigatewayv2_vpc_link" "alb_link" {
  name               = "alb-vpc-link"
  subnet_ids         = slice(aws_subnet.private-subnets[*].id, 0, var.private_subnets_count)
  security_group_ids = [aws_security_group.vpclink_sg.id]
}

resource "aws_security_group" "vpclink_sg" {
  name        = "apigw-vpclink-sg"
  description = "Used by API Gateway VPC Link ENIs"
  vpc_id      = aws_vpc.my-vpc.id
  egress {
    description     = "HTTPS to ALB"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_from_vpclink_sg.id]
  }
  tags = { Name = "apigw-vpclink-sg" }
}
resource "aws_security_group" "alb_from_vpclink_sg" {
  name        = "internal-alb-from-vpclink"
  description = "Allows 443 only from API GW VPC Link"
  vpc_id      = aws_vpc.my-vpc.id
  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.vpclink_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }
  tags = { Name = "internal-alb-from-vpclink" }
}
