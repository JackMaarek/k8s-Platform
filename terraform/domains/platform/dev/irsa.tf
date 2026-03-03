# irsa.tf
# Responsibility: IRSA roles for platform workloads (ArgoCD image updater, etc.)
# Cluster-level IRSA (ESO, Autoscaler) live in _core/shared/dev/iam.tf

# ── ArgoCD image updater ───────────────────────────────────────────────────────
# Reads ECR to detect new image tags and updates ArgoCD Applications automatically

module "irsa_argocd_image_updater" {
  source = "../../../_core/modules/irsa"

  cluster_oidc_issuer_url = local.cluster_oidc_issuer_url
  role_name               = "${local.cluster_id}-argocd-image-updater-role"
  namespace               = "argocd"
  service_account_name    = "argocd-image-updater"

  policy_statements = [
    {
      effect = "Allow"
      actions = [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:DescribeRepositories",
        "ecr:ListImages",
        "ecr:DescribeImages",
        "ecr:BatchGetImage",
      ]
      resources = ["*"]
    },
  ]

  tags = {
    Environment = var.environment
    Component   = "argocd-image-updater"
  }
}
