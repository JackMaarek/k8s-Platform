output "cluster_id" {
  description = "EKS cluster ID — used by node groups and domain modules"
  value       = aws_eks_cluster.this.id
}

output "cluster_arn" {
  description = "EKS cluster ARN"
  value       = aws_eks_cluster.this.arn
}

output "cluster_endpoint" {
  description = "EKS API server endpoint"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded CA data for the cluster"
  value       = aws_eks_cluster.this.certificate_authority[0].data
  sensitive   = true
}

output "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL — used by all IRSA modules"
  value       = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN — used by all IRSA modules"
  value       = aws_iam_openid_connect_provider.this.arn
}

output "node_role_arn" {
  description = "Shared node IAM role ARN — used by all node group modules"
  value       = aws_iam_role.node.arn
}

output "node_role_name" {
  description = "Shared node IAM role name"
  value       = aws_iam_role.node.name
}
