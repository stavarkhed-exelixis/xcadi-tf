resource "databricks_sql_endpoint" "sql_warehouse" {
  count    = var.enable_sql_warehouse ? 1 : 0
  provider = databricks.workspace

  name = "${var.env}-${var.domain_name}-dbx-sql-warehouse"

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

  sql_endpoint_id = databricks_sql_endpoint.sql_warehouse[0].id

  dynamic "access_control" {
    for_each = local.workspace_groups
    content {
      group_name       = access_control.value.display_name
      permission_level = "CAN_MANAGE"
    }
  }
}
