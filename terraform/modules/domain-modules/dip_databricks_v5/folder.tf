resource "databricks_directory" "domain_folder" {
  count    = var.enable_workspace_folder ? 1 : 0
  provider = databricks.workspace
  path     = "/Workspace/${local.normalized_domain_name}${var.team_name != "" ? "-${var.team_name}" : ""}"
}

resource "databricks_permissions" "folder_permission" {
  count          = var.enable_workspace_folder ? 1 : 0
  provider       = databricks.workspace
  directory_path = databricks_directory.domain_folder[0].path

  access_control {
    group_name       = data.databricks_group.this["domain_admins"].display_name
    permission_level = "CAN_MANAGE"
  }

  access_control {
    group_name       = data.databricks_group.this["domain_developers"].display_name
    permission_level = "CAN_RUN"
  }

  dynamic "access_control" {
    for_each = var.git_integration ? [1] : []
    content {
      service_principal_name = databricks_service_principal.svc_git[0].application_id
      permission_level       = "CAN_MANAGE"
    }
  }
}
