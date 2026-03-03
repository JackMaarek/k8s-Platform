# iam.tf
# Responsibility: IRSA roles for cluster-level components (ESO, Cluster Autoscaler)
# Domain-specific IRSA roles are managed in domains/{domain}/dev/irsa.tf

# ── External Secrets Operator ──────────────────────────────────────────────────
# ESO reads secrets from AWS SM on behalf of all ExternalSecret CRDs in the cluster.
# Scoped to secrets under {cluster_name}/* — each domain owns its own path.

module "irsa_eso" {
  source = "../../modules/aws/irsa"

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
  source = "../../modules/aws/irsa"

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

# ── AWS Load Balancer Controller ───────────────────────────────────────────────
# Provisions ALB/NLB from Kubernetes Ingress and Service resources.
# Required for all HTTP ingress routing in the cluster.

module "irsa_aws_lbc" {
  source = "../../modules/aws/irsa"

  cluster_oidc_issuer_url = module.eks.cluster_oidc_issuer_url
  role_name               = "${var.cluster_name}-aws-lbc-role"
  namespace               = "kube-system"
  service_account_name    = "aws-load-balancer-controller"

  policy_statements = [
    {
      effect = "Allow"
      actions = [
        "iam:CreateServiceLinkedRole",
      ]
      resources = ["*"]
    },
    {
      effect = "Allow"
      actions = [
        "ec2:DescribeAccountAttributes",
        "ec2:DescribeAddresses",
        "ec2:DescribeAvailabilityZones",
        "ec2:DescribeInternetGateways",
        "ec2:DescribeVpcs",
        "ec2:DescribeVpcPeeringConnections",
        "ec2:DescribeSubnets",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeInstances",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DescribeTags",
        "ec2:GetCoipPoolUsage",
        "ec2:DescribeCoipPools",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:RevokeSecurityGroupIngress",
        "ec2:CreateSecurityGroup",
        "ec2:CreateTags",
        "ec2:DeleteTags",
        "ec2:DeleteSecurityGroup",
        "elasticloadbalancing:DescribeLoadBalancers",
        "elasticloadbalancing:DescribeLoadBalancerAttributes",
        "elasticloadbalancing:DescribeListeners",
        "elasticloadbalancing:DescribeListenerCertificates",
        "elasticloadbalancing:DescribeSSLPolicies",
        "elasticloadbalancing:DescribeRules",
        "elasticloadbalancing:DescribeTargetGroups",
        "elasticloadbalancing:DescribeTargetGroupAttributes",
        "elasticloadbalancing:DescribeTargetHealth",
        "elasticloadbalancing:DescribeTags",
        "elasticloadbalancing:CreateLoadBalancer",
        "elasticloadbalancing:CreateTargetGroup",
        "elasticloadbalancing:CreateListener",
        "elasticloadbalancing:DeleteListener",
        "elasticloadbalancing:CreateRule",
        "elasticloadbalancing:DeleteRule",
        "elasticloadbalancing:AddTags",
        "elasticloadbalancing:RemoveTags",
        "elasticloadbalancing:ModifyLoadBalancerAttributes",
        "elasticloadbalancing:SetIpAddressType",
        "elasticloadbalancing:SetSecurityGroups",
        "elasticloadbalancing:SetSubnets",
        "elasticloadbalancing:DeleteLoadBalancer",
        "elasticloadbalancing:ModifyTargetGroup",
        "elasticloadbalancing:ModifyTargetGroupAttributes",
        "elasticloadbalancing:DeleteTargetGroup",
        "elasticloadbalancing:RegisterTargets",
        "elasticloadbalancing:DeregisterTargets",
        "elasticloadbalancing:SetWebAcl",
        "elasticloadbalancing:ModifyListener",
        "elasticloadbalancing:AddListenerCertificates",
        "elasticloadbalancing:RemoveListenerCertificates",
        "elasticloadbalancing:ModifyRule",
        "cognito-idp:DescribeUserPoolClient",
        "acm:ListCertificates",
        "acm:DescribeCertificate",
        "iam:ListServerCertificates",
        "iam:GetServerCertificate",
        "waf-regional:GetWebACL",
        "waf-regional:GetWebACLForResource",
        "waf-regional:AssociateWebACL",
        "waf-regional:DisassociateWebACL",
        "wafv2:GetWebACL",
        "wafv2:GetWebACLForResource",
        "wafv2:AssociateWebACL",
        "wafv2:DisassociateWebACL",
        "shield:GetSubscriptionState",
        "shield:DescribeProtection",
        "shield:CreateProtection",
        "shield:DeleteProtection",
      ]
      resources = ["*"]
    },
  ]

  tags = {
    Environment = var.environment
    Component   = "aws-load-balancer-controller"
  }

  depends_on = [module.eks]
}
