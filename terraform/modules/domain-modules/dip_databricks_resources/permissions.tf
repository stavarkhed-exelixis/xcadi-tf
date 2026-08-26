resource "databricks_permissions" "cluster_access" {
  count = var.enable_default_cluster ? 1 : 0
  depends_on = [
    databricks_cluster.Default_Cluster
  ]
  provider   = databricks.workspace
  cluster_id = databricks_cluster.Default_Cluster[0].id

  access_control {
    group_name       = local.workspace_group_display_names["domain_admins"]
    permission_level = "CAN_MANAGE"
  }

  access_control {
    group_name       = local.workspace_group_display_names["domain_developers"]
    permission_level = "CAN_RESTART"
  }

  access_control {
    group_name       = local.workspace_group_display_names["domain_consumers"]
    permission_level = "CAN_ATTACH_TO"
  }

  dynamic "access_control" {
    for_each = local.custom_groups_map
    content {
      group_name       = local.workspace_group_display_names[access_control.key]
      permission_level = "CAN_RESTART"
    }
  }

  dynamic "access_control" {
    for_each = var.git_integration ? [databricks_service_principal.svc_git[0].application_id] : []
    content {
      service_principal_name = access_control.value
      permission_level       = "CAN_RESTART"
    }
  }

  dynamic "access_control" {
    for_each = var.atlan_integration ? [databricks_service_principal.svc_atlan[0].application_id] : []
    content {
      service_principal_name = access_control.value
      permission_level       = "CAN_RESTART"
    }
  }

  dynamic "access_control" {
    for_each = var.dbt_integration ? [databricks_service_principal.svc_dbt[0].application_id] : []
    content {
      service_principal_name = access_control.value
      permission_level       = "CAN_RESTART"
    }
  }

  dynamic "access_control" {
    for_each = var.spotfire_integration ? [databricks_service_principal.svc_spotfire[0].application_id] : []
    content {
      service_principal_name = access_control.value
      permission_level       = "CAN_RESTART"
    }
  }

  dynamic "access_control" {
    for_each = var.tableau_integration ? [databricks_service_principal.svc_tableau[0].application_id] : []
    content {
      service_principal_name = access_control.value
      permission_level       = "CAN_RESTART"
    }
  }

  dynamic "access_control" {
    for_each = var.posit_integration ? [databricks_service_principal.svc_posit[0].application_id] : []
    content {
      service_principal_name = access_control.value
      permission_level       = "CAN_RESTART"
    }
  }

  dynamic "access_control" {
    for_each = var.sas_integration ? [databricks_service_principal.svc_sas[0].application_id] : []
    content {
      service_principal_name = access_control.value
      permission_level       = "CAN_RESTART"
    }
  }
}

resource "databricks_permissions" "token_usage" {
  count         = var.enable_token_usage_permissions ? 1 : 0
  depends_on    = [databricks_mws_workspaces.this]
  provider      = databricks.workspace
  authorization = "tokens"

  access_control {
    group_name       = local.workspace_group_display_names["domain_admins"]
    permission_level = "CAN_USE"
  }
}
