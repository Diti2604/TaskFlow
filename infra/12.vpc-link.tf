resource "aws_apigatewayv2_vpc_link" "alb_link" {
  name               = "alb-vpc-link"
  subnet_ids         = slice(aws_subnet.private-subnets[*].id, 0, var.private_subnets_count) 
  security_group_ids = [
    aws_security_group.alb_http_sg.id,
    aws_security_group.alb_https_sg.id
  ]
}

resource "aws_security_group" "alb_http_sg" {
  name        = "alb-http-sg"
  description = "Allow HTTP inbound traffic"
  vpc_id      = aws_vpc.my-vpc.id

  ingress {
    description = "Allow HTTP traffic from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "alb-http-sg"
  }
}

resource "aws_security_group" "alb_https_sg" {
  name        = "alb-https-sg"
  description = "Allow HTTPS inbound traffic"
  vpc_id      = aws_vpc.my-vpc.id

  ingress {
    description = "Allow HTTPS traffic from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "alb-https-sg"
  }
}

