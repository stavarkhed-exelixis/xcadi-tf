resource "databricks_service_principal" "svc_git" {
  count      = var.git_integration ? 1 : 0
  depends_on = [databricks_mws_workspaces.this]
  provider   = databricks.workspace

  display_name = "${local.selected_env}_${var.domain_name}${var.team_name != "" ? "-${var.team_name}" : ""}_svc_git"
}

resource "databricks_service_principal_secret" "svc_git_secret" {
  count      = var.git_integration ? 1 : 0
  depends_on = [databricks_service_principal.svc_git]
  provider   = databricks.workspace

  service_principal_id = databricks_service_principal.svc_git[count.index].id
  lifetime             = var.git_secret_lifetime
}

resource "aws_secretsmanager_secret" "databricks_git_sp_secret" {
  count      = var.git_integration ? 1 : 0
  depends_on = [databricks_service_principal_secret.svc_git_secret]

  name        = "${local.selected_env}_${var.domain_name}${var.team_name != "" ? "-${var.team_name}" : ""}-git-dbx-svc-principal"
  description = "${local.selected_env}_${var.domain_name}${var.team_name != "" ? "-${var.team_name}" : ""} Databricks git service principal credentials"
}

resource "aws_secretsmanager_secret_version" "databricks_sp_secret_version" {
  count     = var.git_integration ? 1 : 0
  secret_id = aws_secretsmanager_secret.databricks_git_sp_secret[count.index].id

  secret_string = jsonencode({
    client_id     = databricks_service_principal.svc_git[count.index].application_id
    client_secret = databricks_service_principal_secret.svc_git_secret[count.index].secret
  })
}

resource "databricks_service_principal_federation_policy" "this" {
  provider = databricks.mws

  for_each = var.git_integration ? {
    for idx, c in local.repos_to_federate : "${c.repo}:${c.branch}" => c
  } : {}

  service_principal_id = databricks_service_principal.svc_git[0].id

  oidc_policy = {
    issuer    = var.github_issuer_url
    subject   = "repo:${var.github_org_name}/${each.value.repo}:ref:refs/heads/${each.value.branch}"
    audiences = [local.databricks_account_id]
  }
}
