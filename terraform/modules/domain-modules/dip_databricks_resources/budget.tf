resource "databricks_budget" "workspace_budget" {
  count    = var.enable_budget && trimspace(var.budget_email_target) != "" ? 1 : 0
  provider = databricks.mws

  display_name = "dip-dbx-${local.selected_env}-${local.normalized_domain_name}${local.normalized_subdomain_name != "" ? "-${local.normalized_subdomain_name}" : ""}"

  alert_configurations {
    time_period        = "MONTH"
    trigger_type       = "CUMULATIVE_SPENDING_EXCEEDED"
    quantity_type      = "LIST_PRICE_DOLLARS_USD"
    quantity_threshold = tostring(var.budget_monthly_threshold_usd)

    action_configurations {
      action_type = "EMAIL_NOTIFICATION"
      target      = var.budget_email_target
    }
  }

  filter {
    workspace_id {
      operator = "IN"
      values = [
        databricks_mws_workspaces.this.workspace_id
      ]
    }

    tags {
      key = "domain"
      value {
        operator = "IN"
        values   = [local.normalized_domain_name]
      }
    }

    dynamic "tags" {
      for_each = local.normalized_subdomain_name != "" ? [local.normalized_subdomain_name] : []
      content {
        key = "subdomain"
        value {
          operator = "IN"
          values   = [local.normalized_subdomain_name]
        }
      }
    }

    tags {
      key = "environment"
      value {
        operator = "IN"
        values   = [local.selected_env]
      }
    }
  }
}
