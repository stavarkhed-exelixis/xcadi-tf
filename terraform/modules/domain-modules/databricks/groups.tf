locals {
  workspace_groups = {
    devops_admins = {
      display_name         = var.devops_admins_name
      workspace_permission = ["ADMIN"]
      entitlements         = null
    }
  }

  groups_with_entitlements = {
    for k, v in local.workspace_groups : k => v if v.entitlements != null
  }
}

data "databricks_group" "this" {
  for_each     = local.workspace_groups
  provider     = databricks.mws
  display_name = each.value.display_name
}

data "databricks_user" "this" {
  for_each  = var.workspace_users
  provider  = databricks.mws
  user_name = each.value
}

resource "databricks_mws_permission_assignment" "this" {
  for_each     = local.workspace_groups
  provider     = databricks.mws
  workspace_id = databricks_mws_workspaces.this.workspace_id
  principal_id = data.databricks_group.this[each.key].id
  permissions  = each.value.workspace_permission
}

resource "databricks_mws_permission_assignment" "users" {
  for_each     = var.workspace_users
  provider     = databricks.mws
  workspace_id = databricks_mws_workspaces.this.workspace_id
  principal_id = data.databricks_user.this[each.key].id
  permissions  = ["USER"]
}

resource "databricks_entitlements" "this" {
  for_each = local.groups_with_entitlements
  provider = databricks.workspace

  depends_on = [databricks_mws_permission_assignment.this]

  group_id                   = data.databricks_group.this[each.key].id
  allow_cluster_create       = each.value.entitlements.allow_cluster_create
  allow_instance_pool_create = each.value.entitlements.allow_instance_pool_create
  databricks_sql_access      = each.value.entitlements.databricks_sql_access
  workspace_access           = each.value.entitlements.workspace_access
}
