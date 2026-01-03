provider "aws" {
  region = var.aws_region
}

resource "aws_vpc" "my-vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "my-vpc" }
}

data "aws_availability_zones" "available" {
  state = var.availability_zone_state
  filter {
    name   = "zone-type"
    values = ["availability-zone"]
  }
}

resource "aws_subnet" "public-subnets" {
  count                   = var.public_subnets_count
  vpc_id                  = aws_vpc.my-vpc.id
  cidr_block              = var.vpc_public_cidr_blocks[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name                                        = "public-subnet-${count.index}"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1"
  }
  availability_zone = data.aws_availability_zones.available.names[count.index]
}

resource "aws_subnet" "private-subnets" {
  count                   = var.private_subnets_count
  vpc_id                  = aws_vpc.my-vpc.id
  cidr_block              = var.vpc_private_cidr_blocks[count.index]
  map_public_ip_on_launch = false
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  
  tags = {
    Name                                        = "private-subnet-${count.index}"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1"
  }
}
resource "aws_internet_gateway" "my-internet-gateway" {
  vpc_id = aws_vpc.my-vpc.id
  tags = {
    Name = "my-internet-gateway"
  }
}

resource "aws_eip" "elastic-ip-addresses" {
  count  = var.elastic_ip_addresses_count
  domain = "vpc"
  depends_on = [
    aws_internet_gateway.my-internet-gateway
  ]
}

resource "aws_route_table" "my-public-RTs" {
  count  = var.public_route_table_count
  vpc_id = aws_vpc.my-vpc.id
  route {
    cidr_block = var.route_table_cidr_block
    gateway_id = aws_internet_gateway.my-internet-gateway.id
  }
  tags = {
    Name = "my-public-RT-${count.index}"
  }
}


resource "aws_route_table_association" "table-association-of-my-public-RTs" {
  count          = var.table-association-of-my-public-RTs-count
  subnet_id      = aws_subnet.public-subnets[count.index].id
  route_table_id = aws_route_table.my-public-RTs[count.index].id
}

# NAT Gateways for private subnets
resource "aws_nat_gateway" "nat-gateways" {
  count         = var.private_subnets_count
  allocation_id = aws_eip.elastic-ip-addresses[count.index].id
  subnet_id     = aws_subnet.public-subnets[count.index].id
  
  tags = {
    Name = "nat-gateway-${count.index}"
  }
  
  depends_on = [aws_internet_gateway.my-internet-gateway]
}

# Private route tables with NAT gateway routes
resource "aws_route_table" "private-RTs" {
  count  = var.private_subnets_count
  vpc_id = aws_vpc.my-vpc.id
  
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat-gateways[count.index].id
  }
  
  tags = {
    Name = "private-RT-${count.index}"
  }
}

# Associate private subnets with private route tables
resource "aws_route_table_association" "private-RT-associations" {
  count          = var.private_subnets_count
  subnet_id      = aws_subnet.private-subnets[count.index].id
  route_table_id = aws_route_table.private-RTs[count.index].id
}

data "aws_route_table" "main-RT" {
  vpc_id = aws_vpc.my-vpc.id
  filter {
    name   = "association.main"
    values = ["true"]
  }
}
resource "aws_route" "igw_default" {
  route_table_id         = data.aws_route_table.main-RT.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.my-internet-gateway.id
}

# VPC Endpoints Security Group
resource "aws_security_group" "vpc_endpoints" {
  name        = "vpc-endpoints-sg"
  description = "Security group for VPC endpoints"
  vpc_id      = aws_vpc.my-vpc.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.my-vpc.cidr_block]
    description = "Allow HTTPS from VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name = "vpc-endpoints-sg"
  }
}

resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.my-vpc.id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private-subnets[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = aws_vpc.my-vpc.id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private-subnets[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
}



resource "aws_vpc_endpoint" "secrets_manager" {
  vpc_id              = aws_vpc.my-vpc.id
  service_name        = "com.amazonaws.${var.aws_region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private-subnets[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "logs" {
  vpc_id              = aws_vpc.my-vpc.id
  service_name        = "com.amazonaws.${var.aws_region}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private-subnets[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
  
  tags = {
    Name = "cloudwatch-logs-endpoint"
  }
}
