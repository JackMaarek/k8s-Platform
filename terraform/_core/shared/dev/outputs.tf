# outputs.tf
# PUBLIC API — these outputs are consumed by all domain terraform_remote_state data sources.
# Breaking changes require coordination with all domain teams.
# Add new outputs freely. Never remove or rename existing outputs without a migration plan.

# ── Network ────────────────────────────────────────────────────────────────────

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}


output "private_subnet_ids" {
  description = "Private subnet IDs — used by domain node groups"
  value       = module.vpc.private_subnet_ids
}


output "public_subnet_ids" {
  description = "Public subnet IDs — used by load balancers"
  value       = module.vpc.public_subnet_ids
}


# ── Cluster ────────────────────────────────────────────────────────────────────

output "cluster_id" {
  description = "EKS cluster ID — used by domain node group modules"
  value       = module.eks.cluster_id
}


output "cluster_endpoint" {
  description = "EKS API server endpoint"
  value       = module.eks.cluster_endpoint
}


output "cluster_security_group_id" {
  description = "EKS cluster security group ID"
  value       = module.eks.cluster_security_group_id
}


# ── IAM ────────────────────────────────────────────────────────────────────────

output "node_role_arn" {
  description = "Shared node IAM role ARN — used by all domain node group modules"
  value       = module.eks.node_role_arn
}


output "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL — used by domain IRSA modules"
  value       = module.eks.cluster_oidc_issuer_url
}


output "oidc_provider_arn" {
  description = "OIDC provider ARN — used by domain IRSA modules"
  value       = module.eks.oidc_provider_arn
}


output "eso_role_arn" {
  description = "ESO IRSA role ARN — injected into argocd/platform/external-secrets Application"
  value       = module.irsa_eso.role_arn
}


output "cluster_autoscaler_role_arn" {
  description = "Cluster Autoscaler IRSA role ARN"
  value       = module.irsa_cluster_autoscaler.role_arn
}


output "aws_lbc_role_arn" {
  description = "AWS Load Balancer Controller IRSA role ARN"
  value       = module.irsa_aws_lbc.role_arn
}


# ── kubectl ────────────────────────────────────────────────────────────────────

output "configure_kubectl" {
  description = "Command to configure kubectl access to this cluster"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_id}"
}


# ── Access ─────────────────────────────────────────────────────────────────────

output "github_plan_role_arn" {
  description = "GitHub Actions plan role ARN — set as AWS_TERRAFORM_PLAN_ROLE_ARN in GitHub secrets"
  value       = module.github_oidc.plan_role_arn
}


output "github_apply_role_arn" {
  description = "GitHub Actions apply role ARN — set as AWS_TERRAFORM_ROLE_ARN in GitHub secrets"
  value       = module.github_oidc.apply_role_arn
}


output "group_id_platform_devs" {
  description = "IAM Identity Center group ID for platform-devs — add users via AWS console or SCIM"
  value       = module.identity_center.group_id_platform_devs
}


output "group_id_platform_maintainers" {
  description = "IAM Identity Center group ID for platform-maintainers"
  value       = module.identity_center.group_id_platform_maintainers
}


# ── Compliance ─────────────────────────────────────────────────────────────────

output "kms_compliance_key_arn" {
  description = "Compliance KMS key ARN — used by secrets, RDS, S3 in all domains"
  value       = length(module.kms_compliance) > 0 ? module.kms_compliance[0].key_arn : null
}


output "cloudtrail_bucket" {
  description = "Audit log S3 bucket name"
  value       = length(module.cloudtrail) > 0 ? module.cloudtrail[0].audit_bucket_name : null
}


# ── Compliance (conditional on compliance_profile) ─────────────────────────────

output "compliance_profile_active" {
  description = "Active compliance profile for this environment"
  value       = var.compliance_profile
}



