resource "databricks_workspace_binding" "bind_catalog" {
  depends_on     = [databricks_catalog.this]
  count          = var.enable_catalog ? 1 : 0
  provider       = databricks.workspace
  securable_name = databricks_catalog.this[0].name
  securable_type = "catalog"
  workspace_id   = databricks_mws_workspaces.this.workspace_id
}

resource "databricks_catalog" "this" {
  count = var.enable_catalog ? 1 : 0
  depends_on = [
    databricks_external_location.root_dbx_catalog_external_location
  ]
  provider       = databricks.workspace
  storage_root   = "s3://${local.effective_root_storage_bucket}/unity-catalog/${local.selected_env}/${local.normalized_domain_name}${var.team_name != "" ? "/${var.team_name}/" : ""}"
  metastore_id   = var.metastore_id
  name           = "${local.selected_env}-${local.normalized_domain_name}-catalog"
  comment        = var.catalog_comment
  owner          = local.databricks_client_id
  force_destroy  = var.force_destroy # Set to true to delete catalog even if it contains schemas/tables
  isolation_mode = "ISOLATED"
}

resource "databricks_grants" "catalog_access" {
  count    = var.enable_catalog ? 1 : 0
  provider = databricks.workspace
  depends_on = [
    databricks_mws_permission_assignment.this,
    databricks_workspace_binding.bind_catalog
  ]

  catalog = databricks_catalog.this[0].name

  grant {
    principal  = local.workspace_group_display_names["devops_admins"]
    privileges = ["ALL_PRIVILEGES", "MANAGE", "EXTERNAL_USE_SCHEMA"]
  }

  grant {
    principal  = local.workspace_group_display_names["domain_admins"]
    privileges = ["MANAGE", "MODIFY", "USE_SCHEMA", "CREATE_SCHEMA", "USE_CATALOG", "SELECT", "CREATE_TABLE", "CREATE_FUNCTION", "CREATE_MATERIALIZED_VIEW", "CREATE_VOLUME", "APPLY_TAG"]
  }

  grant {
    principal  = local.workspace_group_display_names["domain_developers"]
    privileges = local.selected_env == "dev" ? ["MODIFY", "USE_SCHEMA", "USE_CATALOG", "SELECT", "CREATE_TABLE", "CREATE_FUNCTION", "CREATE_MATERIALIZED_VIEW", "CREATE_VOLUME", "APPLY_TAG"] : ["MODIFY", "USE_SCHEMA", "USE_CATALOG", "SELECT", "APPLY_TAG"]
  }

  grant {
    principal  = local.workspace_group_display_names["domain_consumers"]
    privileges = ["USE_CATALOG", "USE_SCHEMA", "SELECT"]
  }

  dynamic "grant" {
    for_each = var.git_integration ? [1] : []
    content {
      principal  = databricks_service_principal.svc_git[0].application_id
      privileges = ["ALL_PRIVILEGES", "MANAGE", "EXTERNAL_USE_SCHEMA", "MODIFY", "USE_SCHEMA", "CREATE_SCHEMA", "USE_CATALOG", "SELECT", "CREATE_TABLE", "CREATE_FUNCTION", "CREATE_MATERIALIZED_VIEW", "CREATE_VOLUME"]
    }
  }

  lifecycle {
    ignore_changes = [
      grant
    ]
  }
}
