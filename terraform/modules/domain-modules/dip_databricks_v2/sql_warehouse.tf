locals {
  existing_sql_warehouse_id = var.existing_sql_warehouse_id == null ? "" : trimspace(var.existing_sql_warehouse_id)
  create_sql_warehouse      = var.enable_sql_warehouse && local.existing_sql_warehouse_id == ""
}

resource "databricks_sql_endpoint" "sql_warehouse" {
  count    = local.create_sql_warehouse ? 1 : 0
  provider = databricks.workspace

  name = "${local.selected_env}-${var.domain_name}${var.team_name != "" ? "-${var.team_name}" : ""}-dbx-sql-warehouse"

  enable_serverless_compute = false
  cluster_size              = "Small"

  min_num_clusters = 1
  max_num_clusters = 4

  auto_stop_mins       = 20
  spot_instance_policy = "COST_OPTIMIZED"

  enable_photon  = true
  warehouse_type = "PRO"
}

resource "databricks_permissions" "sql_warehouse_permissions" {
  count    = var.enable_sql_warehouse ? 1 : 0
  provider = databricks.workspace

  sql_endpoint_id = local.create_sql_warehouse ? databricks_sql_endpoint.sql_warehouse[0].id : local.existing_sql_warehouse_id

  access_control {
    group_name       = data.databricks_group.this["domain_admins"].display_name
    permission_level = "CAN_MANAGE"
  }

  access_control {
    group_name       = data.databricks_group.this["domain_developers"].display_name
    permission_level = "CAN_USE"
  }

  access_control {
    group_name       = data.databricks_group.this["domain_consumers"].display_name
    permission_level = "CAN_USE"
  }

  dynamic "access_control" {
    for_each = var.git_integration ? [1] : []
    content {
      service_principal_name = databricks_service_principal.svc_git[0].application_id
      permission_level       = "CAN_MANAGE"
    }
  }
}
