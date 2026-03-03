output "trail_arn" {
  description = "CloudTrail trail ARN"
  value       = aws_cloudtrail.this.arn
}

output "audit_bucket_arn" {
  description = "Audit log S3 bucket ARN"
  value       = aws_s3_bucket.audit_logs.arn
}

output "audit_bucket_name" {
  description = "Audit log S3 bucket name"
  value       = aws_s3_bucket.audit_logs.id
}
