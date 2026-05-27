resource "databricks_permissions" "cluster_access" {
  count = var.enable_default_cluster ? 1 : 0
  depends_on = [
    databricks_cluster.Default_Cluster
  ]
  provider   = databricks.workspace
  cluster_id = databricks_cluster.Default_Cluster[0].id

  access_control {
    group_name       = data.databricks_group.this["domain_admins"].display_name
    permission_level = "CAN_MANAGE"
  }

  access_control {
    group_name       = data.databricks_group.this["domain_developers"].display_name
    permission_level = "CAN_RESTART"
  }

  access_control {
    group_name       = data.databricks_group.this["domain_consumers"].display_name
    permission_level = "CAN_ATTACH_TO"
  }

  dynamic "access_control" {
    for_each = var.git_integration ? [1] : []
    content {
      service_principal_name = databricks_service_principal.svc_git[0].application_id
      permission_level       = "CAN_MANAGE"
    }
  }
}

resource "databricks_permissions" "token_usage" {
  count         = var.enable_token_usage_permissions ? 1 : 0
  provider      = databricks.workspace
  authorization = "tokens"

  access_control {
    group_name       = data.databricks_group.this["domain_admins"].display_name
    permission_level = "CAN_USE"
  }
}
