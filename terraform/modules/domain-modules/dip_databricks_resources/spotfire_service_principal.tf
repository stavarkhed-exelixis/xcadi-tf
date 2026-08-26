resource "databricks_service_principal" "svc_spotfire" {
  count      = var.spotfire_integration ? 1 : 0
  depends_on = [databricks_mws_workspaces.this]
  provider   = databricks.workspace

  display_name = "${local.selected_env}_${local.normalized_domain_name}${local.normalized_subdomain_name != "" ? "-${local.normalized_subdomain_name}" : ""}_svc_spotfire"
}

resource "databricks_service_principal_secret" "svc_spotfire_secret" {
  count      = var.spotfire_integration ? 1 : 0
  depends_on = [databricks_service_principal.svc_spotfire]
  provider   = databricks.workspace

  service_principal_id = databricks_service_principal.svc_spotfire[count.index].id
  lifetime             = var.git_secret_lifetime
}

resource "aws_secretsmanager_secret" "databricks_spotfire_sp_secret" {
  count      = var.spotfire_integration ? 1 : 0
  depends_on = [databricks_service_principal_secret.svc_spotfire_secret]

  name        = "${local.selected_env}-${local.normalized_domain_name}${local.normalized_subdomain_name != "" ? "-${local.normalized_subdomain_name}" : ""}-spotfire-dbx-svc-principal"
  description = "${local.selected_env}_${local.normalized_domain_name}${local.normalized_subdomain_name != "" ? "-${local.normalized_subdomain_name}" : ""} Databricks spotfire service principal credentials"
}

resource "aws_secretsmanager_secret_version" "databricks_spotfire_sp_secret_version" {
  count     = var.spotfire_integration ? 1 : 0
  secret_id = aws_secretsmanager_secret.databricks_spotfire_sp_secret[count.index].id

  secret_string = jsonencode({
    client_id     = databricks_service_principal.svc_spotfire[count.index].application_id
    client_secret = databricks_service_principal_secret.svc_spotfire_secret[count.index].secret
  })
}
