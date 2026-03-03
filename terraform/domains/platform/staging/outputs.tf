# outputs.tf
# Outputs in alphabetical order.

output "argocd_image_updater_role_arn" {
  description = "IRSA role ARN for ArgoCD image updater"
  value       = module.irsa_argocd_image_updater.role_arn
}

output "node_group_ids" {
  description = "Map of node group name → node group ID"
  value       = { for k, v in module.node_groups : k => v.node_group_id }
}

output "node_group_arns" {
  description = "Map of node group name → node group ARN"
  value       = { for k, v in module.node_groups : k => v.node_group_arn }
}
