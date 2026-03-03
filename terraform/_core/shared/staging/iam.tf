# iam.tf
# Responsibility: IRSA roles for cluster-level components (ESO, Cluster Autoscaler)
# Domain-specific IRSA roles are managed in domains/{domain}/dev/irsa.tf

# ── External Secrets Operator ──────────────────────────────────────────────────
# ESO reads secrets from AWS SM on behalf of all ExternalSecret CRDs in the cluster.
# Scoped to secrets under {cluster_name}/* — each domain owns its own path.

module "irsa_eso" {
  source = "../../modules/irsa"

  cluster_oidc_issuer_url = module.eks.cluster_oidc_issuer_url
  role_name               = "${var.cluster_name}-eso-role"
  namespace               = "external-secrets"
  service_account_name    = "external-secrets"

  policy_statements = [
    {
      effect  = "Allow"
      actions = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret",
        "secretsmanager:ListSecretVersionIds",
      ]
      resources = ["arn:aws:secretsmanager:${var.aws_region}:*:secret:${var.cluster_name}/*"]
    },
  ]

  tags = {
    Environment = var.environment
    Component   = "external-secrets-operator"
  }

  depends_on = [module.eks]
}

# ── Cluster Autoscaler ─────────────────────────────────────────────────────────
# Scales node groups up/down based on pending pods and node utilization.
# GPU node group starts at 0 — autoscaler provisions on demand.

module "irsa_cluster_autoscaler" {
  source = "../../modules/irsa"

  cluster_oidc_issuer_url = module.eks.cluster_oidc_issuer_url
  role_name               = "${var.cluster_name}-autoscaler-role"
  namespace               = "kube-system"
  service_account_name    = "cluster-autoscaler"

  policy_statements = [
    {
      effect = "Allow"
      actions = [
        "autoscaling:DescribeAutoScalingGroups",
        "autoscaling:DescribeAutoScalingInstances",
        "autoscaling:DescribeLaunchConfigurations",
        "autoscaling:DescribeScalingActivities",
        "autoscaling:DescribeTags",
        "autoscaling:SetDesiredCapacity",
        "autoscaling:TerminateInstanceInAutoScalingGroup",
        "ec2:DescribeImages",
        "ec2:DescribeInstanceTypes",
        "ec2:DescribeLaunchTemplateVersions",
        "ec2:GetInstanceTypesFromInstanceRequirements",
        "eks:DescribeNodegroup",
      ]
      resources = ["*"]
    },
  ]

  tags = {
    Environment = var.environment
    Component   = "cluster-autoscaler"
  }

  depends_on = [module.eks]
}
