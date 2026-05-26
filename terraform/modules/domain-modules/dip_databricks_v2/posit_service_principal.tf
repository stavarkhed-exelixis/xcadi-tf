resource "databricks_service_principal" "svc_posit" {
  count    = var.posit_integration ? 1 : 0
  provider = databricks.workspace

  display_name = "${local.selected_env}_${var.domain_name}${var.team_name != "" ? "-${var.team_name}" : ""}_svc_posit"
}

resource "databricks_service_principal_secret" "svc_posit_secret" {
  count      = var.posit_integration ? 1 : 0
  depends_on = [databricks_service_principal.svc_posit]
  provider   = databricks.workspace

  service_principal_id = databricks_service_principal.svc_posit[count.index].id
  lifetime             = var.git_secret_lifetime
}

resource "aws_secretsmanager_secret" "databricks_posit_sp_secret" {
  count      = var.posit_integration ? 1 : 0
  depends_on = [databricks_service_principal_secret.svc_posit_secret]

  name        = "${local.selected_env}_${var.domain_name}${var.team_name != "" ? "-${var.team_name}" : ""}-posit-dbx-svc-principal"
  description = "${local.selected_env}_${var.domain_name}${var.team_name != "" ? "-${var.team_name}" : ""} Databricks posit service principal credentials"
}

resource "aws_secretsmanager_secret_version" "databricks_posit_sp_secret_version" {
  count     = var.posit_integration ? 1 : 0
  secret_id = aws_secretsmanager_secret.databricks_posit_sp_secret[count.index].id

  secret_string = jsonencode({
    client_id     = databricks_service_principal.svc_posit[count.index].application_id
    client_secret = databricks_service_principal_secret.svc_posit_secret[count.index].secret
  })
}
