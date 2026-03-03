output "secret_arn" {
  description = "Secret ARN — used in IRSA policy statements"
  value       = aws_secretsmanager_secret.this.arn
}

output "secret_name" {
  description = "Full secret name including path — referenced in ExternalSecret CRDs"
  value       = aws_secretsmanager_secret.this.name
}
