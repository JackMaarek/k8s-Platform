# irsa.tf
# Responsibility: IRSA roles for platform workloads (ArgoCD image updater, QuanvNN, etc.)
# Cluster-level IRSA (ESO, Autoscaler) live in _core/shared/dev/iam.tf

# ── ArgoCD image updater ───────────────────────────────────────────────────────
# Reads ECR to detect new image tags and updates ArgoCD Applications automatically

module "irsa_argocd_image_updater" {
  source = "../../../_core/modules/aws/irsa"

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

# ── QuanvNN ML pipeline ────────────────────────────────────────────────────────
# Read-only access to the QuanvNN datasets bucket (see s3.tf).
# Bound to ServiceAccount system:serviceaccount:ml:quanvnn-sa — the SA name is the
# contract between this role and the ml-batch-job Helm chart's ServiceAccount template.

module "irsa_quanvnn" {
  source = "../../../_core/modules/aws/irsa"

  cluster_oidc_issuer_url = local.cluster_oidc_issuer_url
  role_name               = "${local.cluster_id}-quanvnn-role"
  namespace               = "ml"
  service_account_name    = "quanvnn-sa"

  policy_statements = [
    {
      effect    = "Allow"
      actions   = ["s3:ListBucket"]
      resources = [aws_s3_bucket.quanvnn_datasets.arn]
    },
    {
      effect    = "Allow"
      actions   = ["s3:GetObject"]
      resources = ["${aws_s3_bucket.quanvnn_datasets.arn}/*"]
    },
  ]

  tags = {
    Environment = var.environment
    Component   = "quanvnn"
    Workload    = "ml"
  }
}
