resource "databricks_service_principal" "svc_dbt" {
  count      = var.dbt_integration ? 1 : 0
  depends_on = [databricks_mws_workspaces.this]
  provider   = databricks.workspace

  display_name = "${local.selected_env}_${local.normalized_domain_name}${var.team_name != "" ? "-${var.team_name}" : ""}_svc_dbt"
}

resource "databricks_service_principal_secret" "svc_dbt_secret" {
  count      = var.dbt_integration ? 1 : 0
  depends_on = [databricks_service_principal.svc_dbt]
  provider   = databricks.workspace

  service_principal_id = databricks_service_principal.svc_dbt[count.index].id
  lifetime             = var.git_secret_lifetime
}

resource "aws_secretsmanager_secret" "databricks_dbt_sp_secret" {
  count      = var.dbt_integration ? 1 : 0
  depends_on = [databricks_service_principal_secret.svc_dbt_secret]

  name        = "${local.selected_env}-${local.normalized_domain_name}${var.team_name != "" ? "-${var.team_name}" : ""}-dbt-dbx-svc-principal"
  description = "${local.selected_env}_${local.normalized_domain_name}${var.team_name != "" ? "-${var.team_name}" : ""} Databricks dbt service principal credentials"
}

resource "aws_secretsmanager_secret_version" "databricks_dbt_sp_secret_version" {
  count     = var.dbt_integration ? 1 : 0
  secret_id = aws_secretsmanager_secret.databricks_dbt_sp_secret[count.index].id

  secret_string = jsonencode({
    client_id     = databricks_service_principal.svc_dbt[count.index].application_id
    client_secret = databricks_service_principal_secret.svc_dbt_secret[count.index].secret
  })
}
