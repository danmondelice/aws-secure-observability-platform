data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${local.name_prefix}-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.name_prefix}-igw"
  }
}

resource "aws_subnet" "public" {
  for_each = local.subnet_configuration

  vpc_id                  = aws_vpc.main.id
  availability_zone       = each.key
  cidr_block              = each.value.public_cidr
  map_public_ip_on_launch = false

  tags = {
    Name = "${local.name_prefix}-public-${each.key}"
    Tier = "public"
  }
}

resource "aws_subnet" "app" {
  for_each = local.subnet_configuration

  vpc_id                  = aws_vpc.main.id
  availability_zone       = each.key
  cidr_block              = each.value.app_cidr
  map_public_ip_on_launch = false

  tags = {
    Name = "${local.name_prefix}-app-${each.key}"
    Tier = "application"
  }
}

resource "aws_subnet" "db" {
  for_each = local.subnet_configuration

  vpc_id                  = aws_vpc.main.id
  availability_zone       = each.key
  cidr_block              = each.value.db_cidr
  map_public_ip_on_launch = false

  tags = {
    Name = "${local.name_prefix}-db-${each.key}"
    Tier = "database"
  }
}

resource "aws_eip" "nat" {
  for_each = local.nat_gateway_azs

  domain = "vpc"

  tags = {
    Name = "${local.name_prefix}-nat-eip-${each.key}"
  }

  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "main" {
  for_each = local.nat_gateway_azs

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id

  tags = {
    Name = "${local.name_prefix}-nat-${each.key}"
  }

  depends_on = [aws_internet_gateway.main]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.name_prefix}-public-rt"
    Tier = "public"
  }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "app" {
  for_each = local.subnet_configuration

  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.name_prefix}-app-${each.key}-rt"
    Tier = "application"
  }
}

resource "aws_route" "app_egress" {
  for_each = local.subnet_configuration

  route_table_id         = aws_route_table.app[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.main[
    var.nat_gateway_mode == "per_az" ? each.key : local.primary_az
  ].id
}

resource "aws_route_table_association" "app" {
  for_each = aws_subnet.app

  subnet_id      = each.value.id
  route_table_id = aws_route_table.app[each.key].id
}

resource "aws_route_table" "db" {
  for_each = local.subnet_configuration

  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.name_prefix}-db-${each.key}-rt"
    Tier = "database"
  }
}

resource "aws_route_table_association" "db" {
  for_each = aws_subnet.db

  subnet_id      = each.value.id
  route_table_id = aws_route_table.db[each.key].id
}
