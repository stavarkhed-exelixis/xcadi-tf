# workspace.tf

resource "random_string" "network_name_suffix" {
  length  = 6
  special = false
  upper   = false
  lower   = true
  numeric = true
}

resource "databricks_mws_networks" "this" {
  provider           = databricks.mws
  account_id         = local.databricks_account_id
  network_name       = "dip-dbx-${local.selected_env}-${local.normalized_domain_name}-${random_string.network_name_suffix.result}-network"
  security_group_ids = var.security_group_ids
  subnet_ids         = var.subnet_ids
  vpc_id             = var.vpc_id
}

resource "databricks_mws_workspaces" "this" {
  provider                 = databricks.mws
  account_id               = local.databricks_account_id
  aws_region               = var.aws_region
  workspace_name           = "dip-dbx-${local.selected_env}-${local.normalized_domain_name}"
  credentials_id           = databricks_mws_credentials.this.credentials_id
  storage_configuration_id = databricks_mws_storage_configurations.this.storage_configuration_id
  network_id               = databricks_mws_networks.this.network_id

}
