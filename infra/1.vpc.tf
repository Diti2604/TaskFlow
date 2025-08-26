provider "aws" {
  region = var.aws_region
}

resource "aws_vpc" "my-vpc" {
  cidr_block = var.vpc_cidr
  tags       = { Name = "my-vpc" }
}

data "aws_availability_zones" "available" {
  state = var.availability_zone_state
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
# resource "aws_subnet" "public-subnet-2" {
#   vpc_id                  = aws_vpc.my-vpc.id
#   cidr_block              = "10.0.2.0/24"
#   map_public_ip_on_launch = true
#   tags = {
#     Name = "public-subnet-2"
#   }
#   availability_zone = data.aws_availability_zones.available.names[1]
# }
resource "aws_subnet" "private-subnets" {
  count      = var.private_subnets_count
  vpc_id     = aws_vpc.my-vpc.id
  cidr_block = var.vpc_private_cidr_blocks[count.index]
  tags = {
    Name = "private-subnet-${count.index}"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"          = "1"
  }
  availability_zone = data.aws_availability_zones.available.names[count.index]
}
# resource "aws_subnet" "private-subnet-2" {
#   vpc_id     = aws_vpc.my-vpc.id
#   cidr_block = "10.0.4.0/24"
#   tags = {
#     Name = "private-subnet-2"
#   }
#   availability_zone = data.aws_availability_zones.available.names[3]
# }

resource "aws_internet_gateway" "my-internet-gateway" {
  vpc_id = aws_vpc.my-vpc.id

  tags = {
    Name = "my-internet-gateway"
  }
}

resource "aws_eip" "elastic-ip-addresses" {
  count = var.elastic_ip_addresses_count
  depends_on = [
    aws_internet_gateway.my-internet-gateway
  ]
}
# resource "aws_eip" "elastic-ip-address-2" {
#   depends_on = [F
#     aws_internet_gateway.my-internet-gateway
#   ]
# }
resource "aws_nat_gateway" "nat-gateways" {
  count = var.nat_gateway_count
  allocation_id = aws_eip.elastic-ip-addresses[count.index].id
  subnet_id     = aws_subnet.public-subnets[count.index].id

  tags = {
    Name = "nat-gateway-${count.index}"
  }
}
# resource "aws_nat_gateway" "nat-gateway-2" {
#   allocation_id = aws_eip.elastic-ip-address-2.id
#   subnet_id     = aws_subnet.public-subnet-2.id

#   tags = {
#     Name = "nat-gateway-2"
#   }
# }


resource "aws_route_table" "my-private-RTs" {
  count = var.private_route_table_count
  vpc_id = aws_vpc.my-vpc.id
  route {
    cidr_block     = var.route_table_cidr_block
    nat_gateway_id = aws_nat_gateway.nat-gateways[count.index].id
  }
  tags = {
    Name = "my-private-RT-${count.index}"
  }
}
# resource "aws_route_table" "my-private-RT-2" {
#   vpc_id = aws_vpc.my-vpc.id
#   route {
#     cidr_block     = var.route_table_cidr_block
#     nat_gateway_id = aws_nat_gateway.nat-gateways[count.index].id
#   }
#   tags = {
#     Name = "my-private-RT-2"
#   }
# }
resource "aws_route_table" "my-public-RTs" {
  count = var.public_route_table_count
  vpc_id = aws_vpc.my-vpc.id
  route {
    cidr_block = var.route_table_cidr_block
    gateway_id = aws_internet_gateway.my-internet-gateway.id
  }
  tags = {
    Name = "my-public-RT-${count.index}"
  }
}
# resource "aws_route_table" "my-public-RT-2" {
#   vpc_id = aws_vpc.my-vpc.id
#   route {
#     cidr_block = var.route_table_cidr_block
#     gateway_id = aws_internet_gateway.my-internet-gateway.id
#   }
#   tags = {
#     Name = "my-public-RT-2"
#   }
# }


resource "aws_route_table_association" "table-association-of-my-private-RTs" {
  count = var.table-association-of-my-private-RTs-count
  subnet_id      = aws_subnet.private-subnets[count.index].id
  route_table_id = aws_route_table.my-private-RTs[count.index].id
}


# resource "aws_route_table_association" "table-association-of-my-private-RT-2" {
#   subnet_id      = aws_subnet.private-subnet-2.id
#   route_table_id = aws_route_table.my-private-RT-2.id
# }

resource "aws_route_table_association" "table-association-of-my-public-RTs" {
  count = var.table-association-of-my-public-RTs-count
  subnet_id      = aws_subnet.public-subnets[count.index].id
  route_table_id = aws_route_table.my-public-RTs[count.index].id
}

# resource "aws_route_table_association" "table-association-of-my-public-RT-2" {
#   subnet_id      = aws_subnet.public-subnet-2.id
#   route_table_id = aws_route_table.my-public-RT-2.id
# }

#Main route table configuration

data "aws_route_table" "main-RT" {
  vpc_id = aws_vpc.my-vpc.id
  filter {
    name = "association.main"
    values = ["true"]
  }
}

resource "aws_route" "igw_default" {
  route_table_id = data.aws_route_table.main-RT.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.my-internet-gateway.id
}


resource "aws_ec2_instance_connect_endpoint" "ec2_instance_connect" {
  subnet_id = aws_subnet.private-subnets[1].id
  tags = {
    Name = "ec2-instance-connect-endpoint"
  }
}