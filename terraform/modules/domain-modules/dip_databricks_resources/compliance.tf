resource "databricks_compliance_security_profile_workspace_setting" "this" {
  depends_on = [databricks_mws_workspaces.this]
  provider   = databricks.workspace

  compliance_security_profile_workspace {
    is_enabled = !contains(var.compliance_standards, "NONE")

    compliance_standards = contains(var.compliance_standards, "NONE") ? [] : var.compliance_standards
  }
}
