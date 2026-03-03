output "recorder_name" {
  description = "AWS Config recorder name"
  value       = aws_config_configuration_recorder.this.name
}

output "config_bucket" {
  description = "Config snapshots S3 bucket"
  value       = aws_s3_bucket.config.id
}

output "rules_enabled" {
  description = "List of active rule names"
  value       = keys(local.rules)
}
