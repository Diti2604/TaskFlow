
variable "account_id" {
  type        = string
  description = "Account ID of new playgrounds"
  default     = "058264149084"
}



#VPC VARIABLES
variable "aws_region" {
  type        = string
  description = "Value for specifying AWS Region"
  default     = "us-east-1"
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR block"
  default     = "10.0.0.0/16"
}

variable "availability_zone_state" {
  type        = string
  description = "Available AZs state"
  default     = "available"
}

variable "vpc_public_cidr_blocks" {
  type        = list(string)
  description = "Value for the CIDR Blocks of the public subnets in the VPC"
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}
variable "vpc_private_cidr_blocks" {
  type        = list(string)
  description = "Value for the CIDR Blocks of the public subnets in the VPC"
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "public_subnets_count" {
  type        = number
  description = "The number of public subnets in the VPC"
  default     = 2
}
variable "private_subnets_count" {
  type        = number
  description = "The number of private subnets in the VPC"
  default     = 2
}
variable "elastic_ip_addresses_count" {
  type        = number
  description = "The number of EIP addresses in the VPC"
  default     = 2
}

variable "nat_gateway_count" {
  type        = number
  description = "The number of NAT Gateways in the VPC"
  default     = 2
}

variable "route_table_cidr_block" {
  type        = string
  description = "Route Table CIDR block"
  default     = "0.0.0.0/0"
}

variable "public_route_table_count" {
  type        = number
  description = "The number of public route tables in the VPC"
  default     = 2
}
variable "private_route_table_count" {
  type        = number
  description = "The number of private route tables in the VPC"
  default     = 2
}
variable "table-association-of-my-public-RTs-count" {
  type        = number
  description = "The number of table associations public route tables in the VPC"
  default     = 2
}
variable "table-association-of-my-private-RTs-count" {
  type        = number
  description = "The number of table associations private route tables in the VPC"
  default     = 2
}


#RDS VARIABLES

variable "db_subnet_group_name" {
  type = string
  description = "Subnet group name of the database"
  default = "db-subnet-group"
}
variable "db_name" {
  type = string
  description = "Name of the database"
  default = "database1"
}
variable "db_username" {
  type = string
  description = "Name of the username of the database"
  default = "admin"
}


#EKS VARIABLES

variable "cluster_name" {
  type = string
  description = "Name of the cluster in EKS "
  default = "cluster1"
}
variable "node_group_name" {
  type = string
  description = "Name of the nodegorup in EKS "
  default = "node-group-1"
}


variable "max_wait_seconds" {
  description = "Max seconds to wait for ALB and targets to be healthy"
  type        = number
  default     = 600
}