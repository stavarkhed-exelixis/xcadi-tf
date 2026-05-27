# Domain Module Outputs

locals {
  external_location_names_by_layer = {
    root = compact([
      try(databricks_external_location.root_dbx_catalog_external_location[0].name, null)
    ])
    raw = compact(concat(
      [try(databricks_external_location.raw_dbx_external_location[0].name, null)],
      [for resource in values(databricks_external_location.additional_raw_dbx_external_location) : resource.name]
    ))
    staging = compact(concat(
      [try(databricks_external_location.staging_dbx_external_location[0].name, null)],
      [for resource in values(databricks_external_location.additional_staging_dbx_external_location) : resource.name]
    ))
    analytics = compact(concat(
      [try(databricks_external_location.analytics_dbx_external_location[0].name, null)],
      [for resource in values(databricks_external_location.additional_analytics_dbx_external_location) : resource.name]
    ))
  }

  external_location_s3_bucket_names_by_layer = {
    root = compact([
      try(replace(databricks_external_location.root_dbx_catalog_external_location[0].url, "s3://", ""), null)
    ])
    raw = compact(concat(
      [try(replace(databricks_external_location.raw_dbx_external_location[0].url, "s3://", ""), null)],
      [for resource in values(databricks_external_location.additional_raw_dbx_external_location) : replace(resource.url, "s3://", "")]
    ))
    staging = compact(concat(
      [try(replace(databricks_external_location.staging_dbx_external_location[0].url, "s3://", ""), null)],
      [for resource in values(databricks_external_location.additional_staging_dbx_external_location) : replace(resource.url, "s3://", "")]
    ))
    analytics = compact(concat(
      [try(replace(databricks_external_location.analytics_dbx_external_location[0].url, "s3://", ""), null)],
      [for resource in values(databricks_external_location.additional_analytics_dbx_external_location) : replace(resource.url, "s3://", "")]
    ))
  }

  cluster_policy_name = try(coalesce(
    try(databricks_cluster_policy.Default_Cluster_Policy[0].name, null),
    try(databricks_cluster_policy.job_cluster_policy[0].name, null)
  ), null)

  service_principal_credentials_secret_names = {
    for service, secret_name in {
      atlan    = try(aws_secretsmanager_secret.databricks_atlan_sp_secret[0].name, null)
      dbt      = try(aws_secretsmanager_secret.databricks_dbt_sp_secret[0].name, null)
      git      = try(aws_secretsmanager_secret.databricks_git_sp_secret[0].name, null)
      posit    = try(aws_secretsmanager_secret.databricks_posit_sp_secret[0].name, null)
      sas      = try(aws_secretsmanager_secret.databricks_sas_sp_secret[0].name, null)
      spotfire = try(aws_secretsmanager_secret.databricks_spotfire_sp_secret[0].name, null)
      tableau  = try(aws_secretsmanager_secret.databricks_tableau_sp_secret[0].name, null)
    } : service => secret_name if secret_name != null
  }
}

output "databricks_workspace_name" {
  description = "Databricks workspace name."
  value       = databricks_mws_workspaces.this.workspace_name
}

output "databricks_workspace_url" {
  description = "Databricks workspace URL."
  value       = databricks_mws_workspaces.this.workspace_url
}

output "catalog_name" {
  description = "Databricks catalog name."
  value       = try(databricks_catalog.this[0].name, null)
}

output "external_catalog_iam_role_arn" {
  description = "ARN of external catalog IAM role when created by this module."
  value       = try(aws_iam_role.dbx_ext_catalog_role[0].arn, null)
}

output "cluster_name" {
  description = "Primary Databricks cluster name when created by this module."
  value       = try(databricks_cluster.Default_Cluster[0].cluster_name, null)
}

output "cluster_policy_name" {
  description = "Primary Databricks cluster policy name (default policy preferred, otherwise job policy). Null when no cluster policy is enabled."
  value       = local.cluster_policy_name
}

output "external_location_names" {
  description = "Databricks external location names keyed by layer (root/raw/staging/analytics)."
  value       = local.external_location_names_by_layer
}

output "external_location_s3_bucket_names" {
  description = "Databricks external location S3 bucket names keyed by layer (root/raw/staging/analytics)."
  value       = local.external_location_s3_bucket_names_by_layer
}

output "service_principal_credentials_secret_names" {
  description = "AWS Secrets Manager secret names for Databricks service principal credentials created by this module, keyed by integration name."
  value       = local.service_principal_credentials_secret_names
}

