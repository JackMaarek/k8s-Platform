# iam_roles.tf
# Resources: aws_iam_role, aws_iam_policy, aws_iam_role_policy_attachment
#
# One role per environment — scoped to the specific GitHub repo and branch.
# prod role is read-only from local machines; apply is CI-only.

# ── Terraform plan role — all branches (PR validation) ────────────────────────

resource "aws_iam_role" "terraform_plan" {
  name = "${var.cluster_name}-github-terraform-plan"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRoleWithWebIdentity"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      }
      Condition = {
        StringLike = {
          "token.actions.githubusercontent.com:sub" = [
            for repo in var.allowed_repos : "repo:${var.github_org}/${repo}:*"
          ]
        }
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "terraform_plan_readonly" {
  role       = aws_iam_role.terraform_plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# ── Terraform apply role — env branches + main ───────────────────────────────
# Scoped to env branches (dev, staging, prod) and main.
# plan role covers all branches (*) — apply role is restricted to named branches.

resource "aws_iam_role" "terraform_apply" {
  name = "${var.cluster_name}-github-terraform-apply"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRoleWithWebIdentity"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      }
      Condition = {
        # Allow apply from env branches (dev, staging, prod) and the apply branch pattern.
        # Feature branches use the plan role only — no apply from PR branches.
        #
        # Both `ref:refs/heads/<branch>` and `environment:<name>` subjects are
        # accepted because the CI apply job runs under `environment: <env>` —
        # GitHub overrides the sub claim to `environment:<name>` in that case
        # (push/workflow_dispatch outside an environment keeps the ref form).
        StringLike = {
          "token.actions.githubusercontent.com:sub" = flatten([
            for repo in var.allowed_repos : [
              "repo:${var.github_org}/${repo}:ref:refs/heads/${var.apply_branch_pattern}",
              "repo:${var.github_org}/${repo}:ref:refs/heads/dev",
              "repo:${var.github_org}/${repo}:ref:refs/heads/staging",
              "repo:${var.github_org}/${repo}:ref:refs/heads/prod",
              "repo:${var.github_org}/${repo}:environment:dev",
              "repo:${var.github_org}/${repo}:environment:staging",
              "repo:${var.github_org}/${repo}:environment:prod",
            ]
          ])
        }
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_policy" "terraform_apply" {
  name        = "${var.cluster_name}-github-terraform-apply-policy"
  description = "Permissions for Terraform apply via GitHub Actions CI — main branch only"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "TerraformStateBackend"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem",
          "dynamodb:DescribeTable",
        ]
        Resource = [
          "arn:aws:s3:::${var.state_bucket}",
          "arn:aws:s3:::${var.state_bucket}/*",
          "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${var.lock_table}",
        ]
      },
      {
        Sid    = "EKSManagement"
        Effect = "Allow"
        Action = [
          "eks:*",
          "ec2:*",
          "iam:*",
          "autoscaling:*",
          "elasticloadbalancing:*",
          "cloudwatch:*",
          "logs:*",
          "secretsmanager:*",
          "kms:*",
          "ssm:*",
        ]
        Resource = ["*"]
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "terraform_apply" {
  role       = aws_iam_role.terraform_apply.name
  policy_arn = aws_iam_policy.terraform_apply.arn
}
