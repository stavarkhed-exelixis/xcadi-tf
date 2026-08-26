resource "databricks_service_principal" "svc_sas" {
  count      = var.sas_integration ? 1 : 0
  depends_on = [databricks_mws_workspaces.this]
  provider   = databricks.workspace

  display_name = "${local.selected_env}_${local.normalized_domain_name}${local.normalized_subdomain_name != "" ? "-${local.normalized_subdomain_name}" : ""}_svc_sas"
}

resource "databricks_service_principal_secret" "svc_sas_secret" {
  count      = var.sas_integration ? 1 : 0
  depends_on = [databricks_service_principal.svc_sas]
  provider   = databricks.workspace

  service_principal_id = databricks_service_principal.svc_sas[count.index].id
  lifetime             = var.git_secret_lifetime
}

resource "aws_secretsmanager_secret" "databricks_sas_sp_secret" {
  count      = var.sas_integration ? 1 : 0
  depends_on = [databricks_service_principal_secret.svc_sas_secret]

  name        = "${local.selected_env}-${local.normalized_domain_name}${local.normalized_subdomain_name != "" ? "-${local.normalized_subdomain_name}" : ""}-sas-dbx-svc-principal"
  description = "${local.selected_env}_${local.normalized_domain_name}${local.normalized_subdomain_name != "" ? "-${local.normalized_subdomain_name}" : ""} Databricks sas service principal credentials"
}

resource "aws_secretsmanager_secret_version" "databricks_sas_sp_secret_version" {
  count     = var.sas_integration ? 1 : 0
  secret_id = aws_secretsmanager_secret.databricks_sas_sp_secret[count.index].id

  secret_string = jsonencode({
    client_id     = databricks_service_principal.svc_sas[count.index].application_id
    client_secret = databricks_service_principal_secret.svc_sas_secret[count.index].secret
  })
}
