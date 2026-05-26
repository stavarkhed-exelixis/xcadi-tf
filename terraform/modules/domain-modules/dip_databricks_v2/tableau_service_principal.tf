resource "databricks_service_principal" "svc_tableau" {
  count    = var.tableau_integration ? 1 : 0
  provider = databricks.workspace

  display_name = "${local.selected_env}_${var.domain_name}${var.team_name != "" ? "-${var.team_name}" : ""}_svc_tableau"
}

resource "databricks_service_principal_secret" "svc_tableau_secret" {
  count      = var.tableau_integration ? 1 : 0
  depends_on = [databricks_service_principal.svc_tableau]
  provider   = databricks.workspace

  service_principal_id = databricks_service_principal.svc_tableau[count.index].id
  lifetime             = var.git_secret_lifetime
}

resource "aws_secretsmanager_secret" "databricks_tableau_sp_secret" {
  count      = var.tableau_integration ? 1 : 0
  depends_on = [databricks_service_principal_secret.svc_tableau_secret]

  name        = "${local.selected_env}_${var.domain_name}${var.team_name != "" ? "-${var.team_name}" : ""}-tableau-dbx-svc-principal"
  description = "${local.selected_env}_${var.domain_name}${var.team_name != "" ? "-${var.team_name}" : ""} Databricks tableau service principal credentials"
}

resource "aws_secretsmanager_secret_version" "databricks_tableau_sp_secret_version" {
  count     = var.tableau_integration ? 1 : 0
  secret_id = aws_secretsmanager_secret.databricks_tableau_sp_secret[count.index].id

  secret_string = jsonencode({
    client_id     = databricks_service_principal.svc_tableau[count.index].application_id
    client_secret = databricks_service_principal_secret.svc_tableau_secret[count.index].secret
  })
}
