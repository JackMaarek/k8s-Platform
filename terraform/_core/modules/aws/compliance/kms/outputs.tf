output "key_arn" {
  description = "KMS key ARN — used in resource encryption configurations"
  value       = aws_kms_key.this.arn
}

output "key_id" {
  description = "KMS key ID"
  value       = aws_kms_key.this.key_id
}

output "alias_name" {
  description = "KMS key alias"
  value       = aws_kms_alias.this.name
}
