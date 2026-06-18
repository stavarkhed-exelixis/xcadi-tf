locals {
  workspace_groups = {
    devops_admins = {
      display_name         = trimspace(var.devops_admins_name)
      workspace_permission = ["ADMIN"]
      entitlements         = null
    }
    domain_admins = {
      display_name         = trimspace(var.admins_name)
      workspace_permission = ["USER"]
      entitlements = {
        allow_cluster_create       = false
        allow_instance_pool_create = true
        databricks_sql_access      = true
        workspace_access           = true
      }
    }
    domain_developers = {
      display_name         = trimspace(var.developers_name)
      workspace_permission = ["USER"]
      entitlements = {
        allow_cluster_create       = false
        allow_instance_pool_create = false
        databricks_sql_access      = true
        workspace_access           = true
      }
    }
    domain_consumers = {
      display_name         = trimspace(var.consumers_name)
      workspace_permission = ["USER"]
      entitlements = {
        allow_cluster_create       = false
        allow_instance_pool_create = false
        databricks_sql_access      = true
        workspace_access           = false
      }
    }
  }

  groups_with_entitlements = {
    for k, v in local.workspace_groups : k => v if v.entitlements != null
  }

  workspace_group_ids = {
    for key, group in local.workspace_groups : key => data.databricks_group.this[key].id
  }

  workspace_group_display_names = {
    for key, group in local.workspace_groups : key => data.databricks_group.this[key].display_name
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
  principal_id = local.workspace_group_ids[each.key]
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

  group_id                   = local.workspace_group_ids[each.key]
  allow_cluster_create       = each.value.entitlements.allow_cluster_create
  allow_instance_pool_create = each.value.entitlements.allow_instance_pool_create
  databricks_sql_access      = each.value.entitlements.databricks_sql_access
  workspace_access           = each.value.entitlements.workspace_access
}
