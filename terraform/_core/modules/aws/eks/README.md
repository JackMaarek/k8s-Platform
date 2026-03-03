# Module: eks

Provisions an EKS control plane with cluster IAM role, shared node IAM role, OIDC provider for IRSA, CloudWatch log group, and core add-ons (vpc-cni, kube-proxy, coredns, pod-identity-agent).

The OIDC provider output is consumed by every `irsa` module instantiation across all domains.

## Usage

```hcl
module "eks" {
  source = "../../modules/eks"

  cluster_name       = "dev-k8s"
  kubernetes_version = "1.32"
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids
  log_retention_days = 7

  tags = { Environment = "dev" }
}
```

## Files

| File | Resources |
|------|-----------|
| `iam_roles.tf` | `aws_iam_role` (cluster + node), `aws_iam_role_policy_attachment` × 5 |
| `cluster.tf` | `aws_cloudwatch_log_group`, `aws_eks_cluster` |
| `oidc.tf` | `data.tls_certificate`, `aws_iam_openid_connect_provider` |
| `addons.tf` | `aws_eks_addon` × 4 (vpc-cni, kube-proxy, coredns, pod-identity-agent) |

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.6.0 |
| aws | ~> 5.0 |
| tls | ~> 4.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `cluster_name` | EKS cluster name | `string` | — | yes |
| `kubernetes_version` | Kubernetes version | `string` | `"1.32"` | no |
| `private_subnet_ids` | Private subnet IDs for worker nodes | `list(string)` | — | yes |
| `public_subnet_ids` | Public subnet IDs for load balancers | `list(string)` | — | yes |
| `public_access_cidrs` | CIDRs allowed on public API endpoint. Restrict in prod. | `list(string)` | `["0.0.0.0/0"]` | no |
| `log_retention_days` | CloudWatch log retention in days | `number` | `7` | no |
| `tags` | Tags applied to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `cluster_id` | EKS cluster ID |
| `cluster_arn` | EKS cluster ARN |
| `cluster_endpoint` | EKS API server endpoint |
| `cluster_security_group_id` | EKS cluster security group ID |
| `cluster_certificate_authority_data` | Base64 CA data *(sensitive)* |
| `cluster_oidc_issuer_url` | OIDC issuer URL — consumed by all `irsa` modules |
| `oidc_provider_arn` | OIDC provider ARN — consumed by all `irsa` modules |
| `node_role_arn` | Shared node IAM role ARN — consumed by all `nodegroup` modules |
| `node_role_name` | Shared node IAM role name |
