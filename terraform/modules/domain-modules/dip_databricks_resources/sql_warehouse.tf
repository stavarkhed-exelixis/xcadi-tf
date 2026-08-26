locals {
  existing_sql_warehouse_id = var.existing_sql_warehouse_id == null ? "" : trimspace(var.existing_sql_warehouse_id)
  create_sql_warehouse      = var.enable_sql_warehouse && local.existing_sql_warehouse_id == ""
}

resource "databricks_sql_endpoint" "sql_warehouse" {
  count      = local.create_sql_warehouse ? 1 : 0
  depends_on = [databricks_mws_workspaces.this]
  provider   = databricks.workspace

  name = "${local.selected_env}-${local.normalized_domain_name}${local.normalized_subdomain_name != "" ? "-${local.normalized_subdomain_name}" : ""}-dbx-sql-warehouse"

  enable_serverless_compute = false
  cluster_size              = "Small"

  min_num_clusters = 1
  max_num_clusters = 4

  auto_stop_mins       = 20
  spot_instance_policy = "COST_OPTIMIZED"

  enable_photon  = true
  warehouse_type = "PRO"

  dynamic "tags" {
    for_each = length(local.effective_tags) > 0 ? [1] : []
    content {
      dynamic "custom_tags" {
        for_each = local.effective_tags
        content {
          key   = custom_tags.key
          value = custom_tags.value
        }
      }
    }
  }
}

resource "databricks_permissions" "sql_warehouse_permissions" {
  count      = var.enable_sql_warehouse ? 1 : 0
  depends_on = [databricks_mws_workspaces.this]
  provider   = databricks.workspace

  sql_endpoint_id = local.create_sql_warehouse ? databricks_sql_endpoint.sql_warehouse[0].id : local.existing_sql_warehouse_id

  access_control {
    group_name       = local.workspace_group_display_names["domain_admins"]
    permission_level = "CAN_MANAGE"
  }

  access_control {
    group_name       = local.workspace_group_display_names["domain_developers"]
    permission_level = "CAN_USE"
  }

  access_control {
    group_name       = local.workspace_group_display_names["domain_consumers"]
    permission_level = "CAN_USE"
  }

  dynamic "access_control" {
    for_each = local.custom_groups_map
    content {
      group_name       = local.workspace_group_display_names[access_control.key]
      permission_level = "CAN_USE"
    }
  }

  dynamic "access_control" {
    for_each = var.git_integration ? [databricks_service_principal.svc_git[0].application_id] : []
    content {
      service_principal_name = access_control.value
      permission_level       = "CAN_USE"
    }
  }

  dynamic "access_control" {
    for_each = var.atlan_integration ? [databricks_service_principal.svc_atlan[0].application_id] : []
    content {
      service_principal_name = access_control.value
      permission_level       = "CAN_USE"
    }
  }

  dynamic "access_control" {
    for_each = var.dbt_integration ? [databricks_service_principal.svc_dbt[0].application_id] : []
    content {
      service_principal_name = access_control.value
      permission_level       = "CAN_USE"
    }
  }

  dynamic "access_control" {
    for_each = var.spotfire_integration ? [databricks_service_principal.svc_spotfire[0].application_id] : []
    content {
      service_principal_name = access_control.value
      permission_level       = "CAN_USE"
    }
  }

  dynamic "access_control" {
    for_each = var.tableau_integration ? [databricks_service_principal.svc_tableau[0].application_id] : []
    content {
      service_principal_name = access_control.value
      permission_level       = "CAN_USE"
    }
  }

  dynamic "access_control" {
    for_each = var.posit_integration ? [databricks_service_principal.svc_posit[0].application_id] : []
    content {
      service_principal_name = access_control.value
      permission_level       = "CAN_USE"
    }
  }

  dynamic "access_control" {
    for_each = var.sas_integration ? [databricks_service_principal.svc_sas[0].application_id] : []
    content {
      service_principal_name = access_control.value
      permission_level       = "CAN_USE"
    }
  }
}
