# Private Subnets for Fargate
# Fargate requires private subnets with NAT Gateway access

# Create private subnets in 2 different AZs
resource "aws_subnet" "private_1" {
  vpc_id            = var.vpc_id
  cidr_block        = "172.31.64.0/20"  # 172.31.64.0 - 172.31.79.255
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name                                                    = "${var.project_name}-${var.environment}-private-subnet-1"
    "kubernetes.io/role/internal-elb"                       = "1"
    "kubernetes.io/cluster/${var.project_name}-${var.environment}-cluster" = "shared"
  }
}

resource "aws_subnet" "private_2" {
  vpc_id            = var.vpc_id
  cidr_block        = "172.31.80.0/20"  # 172.31.80.0 - 172.31.95.255
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name                                                    = "${var.project_name}-${var.environment}-private-subnet-2"
    "kubernetes.io/role/internal-elb"                       = "1"
    "kubernetes.io/cluster/${var.project_name}-${var.environment}-cluster" = "shared"
  }
}

# Data source to get available AZs
data "aws_availability_zones" "available" {
  state = "available"
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-${var.environment}-nat-eip"
  }
}

# NAT Gateway (required for Fargate to pull images and access AWS APIs)
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = data.aws_subnet.public_1.id  # Must be in a public subnet

  tags = {
    Name = "${var.project_name}-${var.environment}-nat-gateway"
  }

  depends_on = [aws_eip.nat]
}

# Get first public subnet from VPC (for NAT Gateway)
data "aws_subnet" "public_1" {
  vpc_id            = var.vpc_id
  availability_zone = data.aws_availability_zones.available.names[0]
  default_for_az    = true
}

# Route table for private subnets
resource "aws_route_table" "private" {
  vpc_id = var.vpc_id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-private-rt"
  }
}

# Associate route table with private subnets
resource "aws_route_table_association" "private_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_2" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private.id
}

# Outputs for private subnet IDs
output "private_subnet_ids" {
  description = "Private subnet IDs for Fargate"
  value       = [aws_subnet.private_1.id, aws_subnet.private_2.id]
}
