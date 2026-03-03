# Module: vpc

Provisions a production-ready VPC with public/private subnet topology, internet gateway, NAT gateways, and route tables.

Cost optimization: set `single_nat_gateway = true` in non-production environments to use one NAT gateway instead of one per AZ (~$65/month saved per unused gateway).

## Usage

```hcl
module "vpc" {
  source = "../../modules/vpc"

  name               = "dev-k8s"
  cluster_name       = "dev-k8s"
  cidr               = "10.0.0.0/16"
  single_nat_gateway = true

  private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnet_cidrs  = ["10.0.101.0/24", "10.0.102.0/24"]
  availability_zones   = ["eu-west-3a", "eu-west-3b"]

  tags = { Environment = "dev" }
}
```

## Files

| File | Resources |
|------|-----------|
| `vpc.tf` | `aws_vpc` |
| `subnets.tf` | `aws_subnet` (private × n, public × n) |
| `internet_gateway.tf` | `aws_internet_gateway` |
| `nat_gateway.tf` | `aws_eip`, `aws_nat_gateway` |
| `route_tables.tf` | `aws_route_table`, `aws_route_table_association` |

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.6.0 |
| aws | ~> 5.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `name` | Name prefix for all VPC resources | `string` | — | yes |
| `cluster_name` | EKS cluster name — used for subnet tags required by AWS LBC | `string` | — | yes |
| `cidr` | CIDR block for the VPC | `string` | — | yes |
| `private_subnet_cidrs` | CIDR blocks for private subnets — one per AZ (min 2) | `list(string)` | — | yes |
| `public_subnet_cidrs` | CIDR blocks for public subnets — one per AZ (min 2) | `list(string)` | — | yes |
| `availability_zones` | Availability zones — must match subnet CIDR count (min 2) | `list(string)` | — | yes |
| `single_nat_gateway` | Use one NAT gateway instead of one per AZ. Recommended for non-prod. | `bool` | `false` | no |
| `tags` | Tags applied to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `vpc_id` | VPC ID |
| `vpc_cidr` | VPC CIDR block |
| `private_subnet_ids` | Private subnet IDs — used by EKS node groups |
| `public_subnet_ids` | Public subnet IDs — used by load balancers |
| `nat_gateway_ids` | NAT gateway IDs |
| `internet_gateway_id` | Internet gateway ID |
