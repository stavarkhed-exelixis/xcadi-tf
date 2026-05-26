# Creates the S3 prefix, UC storage credential, and external location that
# must exist before databricks_catalog can use the root_storage_bucket path.
# All resources are gated by enable_catalog so they are only created when needed.

resource "aws_s3_object" "dbx_unity_catalog_folder_creation" {
  count   = var.enable_catalog ? 1 : 0
  bucket  = local.effective_root_storage_bucket
  key     = "unity-catalog/${local.selected_env}/${var.domain_name}/${var.team_name != "" ? "${var.team_name}/" : ""}"
  content = ""
}

resource "databricks_storage_credential" "dbx_root_storage_credential" {
  count    = var.enable_catalog ? 1 : 0
  provider = databricks.workspace

  name    = "${local.selected_env}-${var.domain_name}${var.team_name != "" ? "-${var.team_name}" : ""}-root-dbx-uc-storage_credential"
  comment = "Credential for root ${local.selected_env}_${var.domain_name}${var.team_name != "" ? "_${var.team_name}" : ""} external location"
  aws_iam_role {
    role_arn = local.effective_cross_account_role_arn
  }
  isolation_mode = "ISOLATION_MODE_ISOLATED"
  force_update   = true
}

resource "databricks_external_location" "root_dbx_catalog_external_location" {
  count = var.enable_catalog ? 1 : 0
  depends_on = [
    databricks_mws_workspaces.this,
    aws_s3_object.dbx_unity_catalog_folder_creation
  ]
  provider = databricks.workspace

  name            = "${local.selected_env}-${var.domain_name}${var.team_name != "" ? "-${var.team_name}" : ""}-uc-root-external_location"
  url             = "s3://${local.effective_root_storage_bucket}/unity-catalog/${local.selected_env}/${var.domain_name}/${var.team_name != "" ? "${var.team_name}/" : ""}"
  credential_name = databricks_storage_credential.dbx_root_storage_credential[0].name
  comment         = "ROOT External location for ${local.selected_env}_${var.domain_name}${var.team_name != "" ? "_${var.team_name}" : ""} catalog"
  force_update    = true
  isolation_mode  = "ISOLATION_MODE_ISOLATED"
}

resource "databricks_grants" "uc_root_ext_location_grants" {
  count    = var.enable_catalog ? 1 : 0
  provider = databricks.workspace
  depends_on = [
    databricks_mws_permission_assignment.this
  ]
  external_location = databricks_external_location.root_dbx_catalog_external_location[0].name

  grant {
    principal  = data.databricks_group.this["devops_admins"].display_name
    privileges = ["ALL_PRIVILEGES", "MANAGE", "CREATE_EXTERNAL_TABLE", "CREATE_MANAGED_STORAGE"]
  }
}
