# ebs_csi.tf
# Resources: IAM role for EBS CSI controller, aws-ebs-csi-driver EKS addon.
#
# EKS 1.23+ removed the in-tree kubernetes.io/aws-ebs provisioner — any PVC
# without an explicit CSI-backed StorageClass stays Pending forever. The
# addon is installed AFTER node groups (like CoreDNS) because the CSI
# controller Deployment needs a node to schedule on.
#
# A default gp3 StorageClass is applied declaratively by ArgoCD at wave -3
# (see kubernetes/manifests/storage/default-storageclass.yaml).

data "aws_caller_identity" "ebs_csi" {}

locals {
  ebs_csi_oidc_issuer = replace(local.cluster_oidc_issuer_url, "https://", "")
}

data "aws_iam_policy_document" "ebs_csi_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.ebs_csi.account_id}:oidc-provider/${local.ebs_csi_oidc_issuer}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.ebs_csi_oidc_issuer}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.ebs_csi_oidc_issuer}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ebs_csi" {
  name               = "${local.cluster_id}-ebs-csi-role"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_trust.json

  tags = {
    Environment = var.environment
    Component   = "ebs-csi-driver"
  }
}

resource "aws_iam_role_policy_attachment" "ebs_csi_managed" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name                = local.cluster_id
  addon_name                  = "aws-ebs-csi-driver"
  service_account_role_arn    = aws_iam_role.ebs_csi.arn
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  tags = {
    Environment = var.environment
  }

  depends_on = [
    module.node_groups,
    aws_iam_role_policy_attachment.ebs_csi_managed,
  ]
}
