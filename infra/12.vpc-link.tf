resource "aws_apigatewayv2_vpc_link" "alb_link" {
  name               = "alb-vpc-link"
  subnet_ids         = slice(aws_subnet.private-subnets[*].id, 0, var.private_subnets_count)
  security_group_ids = [aws_security_group.apigw_vpclink_sg.id]
}
resource "aws_security_group" "apigw_vpclink_sg" {
  name        = "apigw-vpclink-sg"
  description = "API Gateway VPC Link ENIs"
  vpc_id      = aws_vpc.my-vpc.id

  revoke_rules_on_delete = true
  tags = { Name = "apigw-vpclink-sg" }
}

resource "aws_security_group" "alb_from_vpclink_sg" {
  name        = "internal-alb-from-vpclink"
  description = "Allow only 443 from VPC Link"
  vpc_id      = aws_vpc.my-vpc.id

  revoke_rules_on_delete = true
  tags = { Name = "internal-alb-from-vpclink" }
}

resource "aws_security_group_rule" "vpclink_egress_alb" {
  type                     = "egress"
  security_group_id        = aws_security_group.apigw_vpclink_sg.id
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb_from_vpclink_sg.id
  description              = "HTTPS to ALB"
}


resource "aws_security_group_rule" "alb_ingress_vpclink" {
  type                     = "ingress"
  security_group_id        = aws_security_group.alb_from_vpclink_sg.id
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.apigw_vpclink_sg.id
  description              = "HTTPS from VPC Link"
}

resource "aws_security_group_rule" "alb_egress_to_vpc" {
  type              = "egress"
  security_group_id = aws_security_group.alb_from_vpclink_sg.id
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = [var.vpc_cidr] 
}
