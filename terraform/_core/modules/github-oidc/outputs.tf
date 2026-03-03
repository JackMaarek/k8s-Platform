output "plan_role_arn" {
  description = "IAM role ARN for terraform plan — set as AWS_TERRAFORM_PLAN_ROLE_ARN in GitHub secrets"
  value       = aws_iam_role.terraform_plan.arn
}

output "apply_role_arn" {
  description = "IAM role ARN for terraform apply — set as AWS_TERRAFORM_ROLE_ARN in GitHub secrets"
  value       = aws_iam_role.terraform_apply.arn
}

output "oidc_provider_arn" {
  description = "GitHub OIDC provider ARN"
  value       = aws_iam_openid_connect_provider.github.arn
}
