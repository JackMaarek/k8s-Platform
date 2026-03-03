# cluster.tf
# Responsibility: EKS control plane, OIDC provider, cluster add-ons
# The cluster is provisioned once and shared across all domains.

module "eks" {
  source = "../../modules/eks"

  cluster_name        = var.cluster_name
  kubernetes_version  = var.kubernetes_version
  private_subnet_ids  = module.vpc.private_subnet_ids
  public_subnet_ids   = module.vpc.public_subnet_ids
  public_access_cidrs = var.public_access_cidrs
  log_retention_days  = 30

  tags = {
    Environment = var.environment
  }

  depends_on = [module.vpc]
}
