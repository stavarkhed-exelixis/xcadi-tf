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
  provider     = databricks.workspace
  storage_root = "s3://${var.root_storage_bucket}/unity-catalog/${var.env}/${var.domain_name}${var.team_name != "" ? "/${var.team_name}/" : ""}"
  metastore_id = var.metastore_id
  name         = "${var.env}-${var.domain_name}-catalog"
  comment      = var.catalog_comment
  # Optional arguments
  #owner         = data.databricks_group.domain_admins.display_name
  force_destroy  = var.force_destroy # Set to true to delete catalog even if it contains schemas/tables
  isolation_mode = "ISOLATED"
}

resource "databricks_grants" "catalog_access" {
  count    = var.enable_catalog ? 1 : 0
  provider = databricks.workspace

  catalog = databricks_catalog.this[0].name

  dynamic "grant" {
    for_each = local.workspace_groups

    content {
      principal  = data.databricks_group.this[grant.key].display_name
      privileges = ["ALL_PRIVILEGES", "MANAGE", "EXTERNAL_USE_SCHEMA"]
    }
  }
}
