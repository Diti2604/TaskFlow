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
    Name = "public-subnet-${count.index}"
  }
  availability_zone = data.aws_availability_zones.available.names[count.index]
}

resource "aws_subnet" "private-subnets" {
  count      = var.private_subnets_count
  vpc_id     = aws_vpc.my-vpc.id
  cidr_block = var.vpc_private_cidr_blocks[count.index]
  tags = {
    Name                                        = "private-subnet-${count.index}"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1"
  }
  availability_zone = data.aws_availability_zones.available.names[count.index]
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

resource "aws_nat_gateway" "nat-gateways" {
  count         = var.nat_gateway_count
  allocation_id = aws_eip.elastic-ip-addresses[count.index].id
  subnet_id     = aws_subnet.public-subnets[count.index].id

  tags = {
    Name = "nat-gateway-${count.index}"
  }
}

resource "aws_route_table" "my-private-RTs" {
  count  = var.private_route_table_count
  vpc_id = aws_vpc.my-vpc.id
  route {
    cidr_block     = var.route_table_cidr_block
    nat_gateway_id = aws_nat_gateway.nat-gateways[0].id
  }
  tags = {
    Name = "my-private-RT-${count.index}"
  }
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

resource "aws_route_table_association" "table-association-of-my-private-RTs" {
  count          = var.table-association-of-my-private-RTs-count
  subnet_id      = aws_subnet.private-subnets[count.index].id
  route_table_id = aws_route_table.my-private-RTs[count.index].id
}
resource "aws_route_table_association" "table-association-of-my-public-RTs" {
  count          = var.table-association-of-my-public-RTs-count
  subnet_id      = aws_subnet.public-subnets[count.index].id
  route_table_id = aws_route_table.my-public-RTs[count.index].id
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
resource "aws_ec2_instance_connect_endpoint" "ec2_instance_connect" {
  subnet_id = aws_subnet.private-subnets[1].id
  tags = {
    Name = "ec2-instance-connect-endpoint"
  }
}
