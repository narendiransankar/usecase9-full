


resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name        = "${var.name_prefix != null ? var.name_prefix : "eks-vpc"}"
    Environment = var.env
    Terraform   = "true"
  }
}

# If AZ list not provided, fetch the first 2 AZs in the region
data "aws_availability_zones" "available" {
  state = "available"
}
locals {
  az_list = length(var.azs) > 0 ? var.azs : slice(data.aws_availability_zones.available.names, 0, 2)
}

# Create public subnets in each AZ
resource "aws_subnet" "public" {
  count                   = length(local.az_list)
  vpc_id                  = aws_vpc.this.id
  cidr_block = length(var.public_subnet_cidrs) == length(local.az_list) ? var.public_subnet_cidrs[count.index] : cidrsubnet(var.vpc_cidr, 8, count.index)
  tags = {
    Name                           = "${var.env}-public-${local.az_list[count.index]}"
    "kubernetes.io/role/elb"       = "1"    # tag to denote public LB can be placed here
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    Environment                    = var.env
  }
}

# Create private subnets in each AZ
resource "aws_subnet" "private" {
  count                   = length(local.az_list)
  vpc_id                  = aws_vpc.this.id
  cidr_block = length(var.private_subnet_cidrs) == length(local.az_list) ? var.private_subnet_cidrs[count.index] : cidrsubnet(var.vpc_cidr, 8, count.index + length(local.az_list))
  map_public_ip_on_launch = false
  tags = {
    Name                             = "${var.env}-private-${local.az_list[count.index]}"
    "kubernetes.io/role/internal-elb"= "1"    # tag to denote internal LB (for internal services) can use these subnets
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    Environment                      = var.env
  }
}

# Internet Gateway for VPC (for public subnet egress)
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "${var.env}-vpc-igw"
  }
}

# Public route table (one that routes 0.0.0.0/0 to IGW)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.env}-public-rt" }
}
resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

# Associate all public subnets with the public route table
resource "aws_route_table_association" "public_assoc" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# NAT Gateways and Elastic IPs for each AZ (for private subnet egress)
resource "aws_eip" "nat" {
  count      = length(aws_subnet.public)
  domain         = "vpc"
  depends_on = [aws_internet_gateway.igw]  # ensure IGW is ready before EIP (to avoid race in some cases)
  tags       = { Name = "${var.env}-nat-eip-${local.az_list[count.index]}" }
}
resource "aws_nat_gateway" "nat" {
  count         = length(aws_subnet.public)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id   # place NAT GW in a public subnet
  tags          = { Name = "${var.env}-nat-${local.az_list[count.index]}" }
}

# Private route tables, each with default route to a NAT gateway in the same AZ
resource "aws_route_table" "private" {
  count = length(aws_subnet.private)
  vpc_id = aws_vpc.this.id
  tags = { Name = "${var.env}-private-rt-${local.az_list[count.index]}" }
}
resource "aws_route" "private_to_nat" {
  count                  = length(aws_subnet.private)
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  # route through the NAT in the corresponding AZ (assumes same index aligns AZ)
  nat_gateway_id         = aws_nat_gateway.nat[count.index].id
}
resource "aws_route_table_association" "private_assoc" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}
