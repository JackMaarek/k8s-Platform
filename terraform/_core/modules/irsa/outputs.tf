output "role_arn" {
  description = "IAM role ARN — annotate on the Kubernetes service account: eks.amazonaws.com/role-arn"
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "IAM role name"
  value       = aws_iam_role.this.name
}
