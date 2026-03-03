# iam_policy.tf
# Resources: data aws_iam_policy_document (permissions), aws_iam_policy, aws_iam_role_policy_attachment

data "aws_iam_policy_document" "permissions" {
  dynamic "statement" {
    for_each = var.policy_statements

    content {
      effect    = statement.value.effect
      actions   = statement.value.actions
      resources = statement.value.resources
    }
  }
}

resource "aws_iam_policy" "this" {
  name   = "${var.role_name}-policy"
  policy = data.aws_iam_policy_document.permissions.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.this.arn
}
