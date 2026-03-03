# nat_gateway.tf
# Resources: aws_eip + aws_nat_gateway
# Single NAT in non-prod (cost ~$65/month per extra gateway), multi-NAT in prod for HA

locals {
  nat_count = var.single_nat_gateway ? 1 : length(var.private_subnet_cidrs)
}

resource "aws_eip" "nat" {
  count  = local.nat_count
  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.name}-nat-eip-${count.index + 1}"
  })

  depends_on = [aws_internet_gateway.this]
}

resource "aws_nat_gateway" "this" {
  count = local.nat_count

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(var.tags, {
    Name = "${var.name}-nat-${count.index + 1}"
  })

  depends_on = [aws_internet_gateway.this]
}
