# Domain Module Outputs

output "databricks_workspace_id" {
  description = "Databricks workspace ID (MWS workspace)."
  value       = databricks_mws_workspaces.this.workspace_id
}

output "databricks_workspace_name" {
  description = "Databricks workspace name."
  value       = databricks_mws_workspaces.this.workspace_name
}

output "databricks_workspace_url" {
  description = "Databricks workspace URL."
  value       = databricks_mws_workspaces.this.workspace_url
}

output "workspace_groups" {
  value = local.workspace_groups
}
