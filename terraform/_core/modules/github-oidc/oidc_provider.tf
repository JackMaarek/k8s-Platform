# oidc_provider.tf
# Resource: aws_iam_openid_connect_provider (GitHub Actions OIDC)
#
# Allows GitHub Actions workflows to assume AWS IAM roles without storing
# any static credentials in GitHub Secrets.
# Only the role ARN is stored as a GitHub secret — not a key or password.
#
# Trust is scoped to a specific GitHub org/repo to prevent other repos
# from assuming the role.

data "aws_caller_identity" "current" {}

data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]

  tags = var.tags
}
