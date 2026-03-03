output "flow_log_id" {
  description = "VPC flow log ID"
  value       = aws_flow_log.this.id
}

output "log_group_name" {
  description = "CloudWatch log group name"
  value       = aws_cloudwatch_log_group.flow_logs.name
}
