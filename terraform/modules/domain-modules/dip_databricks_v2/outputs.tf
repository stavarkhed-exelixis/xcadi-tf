# Domain Module Outputs

output "databricks_workspace_name" {
  description = "Databricks workspace name."
  value       = databricks_mws_workspaces.this.workspace_name
}

output "databricks_workspace_url" {
  description = "Databricks workspace URL."
  value       = databricks_mws_workspaces.this.workspace_url
}

output "databricks_workspace_id" {
  description = "Databricks workspace ID (MWS workspace)."
  value       = databricks_mws_workspaces.this.workspace_id
}

output "external_catalog_iam_role_arn" {
  description = "ARN of external catalog IAM role when created by this module."
  value       = try(aws_iam_role.dbx_ext_catalog_role[0].arn, null)
}

output "catalog_name" {
  description = "Databricks catalog name."
  value       = try(databricks_catalog.this[0].name, null)
}

output "external_location_names" {
  description = "All Databricks external location names created by this module."
  value = sort(distinct(compact(concat(
    [try(databricks_external_location.root_dbx_catalog_external_location[0].name, null)],
    [try(databricks_external_location.raw_dbx_external_location[0].name, null)],
    [try(databricks_external_location.staging_dbx_external_location[0].name, null)],
    [try(databricks_external_location.analytics_dbx_external_location[0].name, null)],
    [for r in values(databricks_external_location.additional_raw_dbx_external_location) : r.name],
    [for r in values(databricks_external_location.additional_staging_dbx_external_location) : r.name],
    [for r in values(databricks_external_location.additional_analytics_dbx_external_location) : r.name]
  ))))
}

output "external_location_s3_bucket_names" {
  description = "S3 bucket names with prefixes used by Databricks external locations (without s3:// prefix)."
  value = sort(distinct(compact([
    for url in compact(concat(
      [try(databricks_external_location.root_dbx_catalog_external_location[0].url, null)],
      [try(databricks_external_location.raw_dbx_external_location[0].url, null)],
      [try(databricks_external_location.staging_dbx_external_location[0].url, null)],
      [try(databricks_external_location.analytics_dbx_external_location[0].url, null)],
      [for r in values(databricks_external_location.additional_raw_dbx_external_location) : r.url],
      [for r in values(databricks_external_location.additional_staging_dbx_external_location) : r.url],
      [for r in values(databricks_external_location.additional_analytics_dbx_external_location) : r.url]
    )) : replace(url, "s3://", "")
  ])))
}

output "access_group_names" {
  description = "Workspace access group names assigned by this module."
  value       = sort([for g in values(data.databricks_group.this) : g.display_name])
}

output "cluster_policy_name" {
  description = "Primary Databricks cluster policy name (default policy preferred, otherwise job policy)."
  value = coalesce(
    try(databricks_cluster_policy.Default_Cluster_Policy[0].name, null),
    try(databricks_cluster_policy.job_cluster_policy[0].name, null)
  )
}

output "cluster_policy_names" {
  description = "All Databricks cluster policy names created by this module."
  value = compact([
    try(databricks_cluster_policy.Default_Cluster_Policy[0].name, null),
    try(databricks_cluster_policy.job_cluster_policy[0].name, null)
  ])
}

