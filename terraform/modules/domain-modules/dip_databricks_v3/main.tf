# provider.tf

terraform {
  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.110.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Fetch Databricks credentials from AWS Secrets Manager.
# The secret must be a JSON document with keys:
#   { "client_id": "...", "client_secret": "...", "account_id": "..." }
data "aws_secretsmanager_secret_version" "databricks" {
  secret_id = local.effective_databricks_credentials_secret_name
}

locals {
  selected_env                                 = one(var.env)
  env_account_id                               = var.environment_account_ids[local.selected_env]
  effective_databricks_credentials_secret_name = coalesce(var.databricks_credentials_secret_name, "databricks/dip-${local.selected_env}/credentials")
  effective_cross_account_role_arn             = coalesce(var.cross_account_role_arn, "arn:aws:iam::${var.cross_account_role_account_id}:role/exelixis-dip-${local.selected_env}-databricks-cross-account-role")
  effective_root_storage_bucket                = coalesce(var.root_storage_bucket, "exelixis-dip-${local.selected_env}-${var.aws_region}-${var.cross_account_role_account_id}-dbx-storage")

  databricks_credentials   = jsondecode(data.aws_secretsmanager_secret_version.databricks.secret_string)
  databricks_client_id     = local.databricks_credentials["client_id"]
  databricks_client_secret = local.databricks_credentials["client_secret"]
  databricks_account_id    = local.databricks_credentials["account_id"]
}

provider "databricks" {
  alias         = "mws"
  host          = "https://accounts.cloud.databricks.com"
  client_id     = local.databricks_client_id
  client_secret = local.databricks_client_secret
  account_id    = local.databricks_account_id
}

provider "databricks" {
  alias         = "workspace"
  host          = databricks_mws_workspaces.this.workspace_url
  workspace_id  = databricks_mws_workspaces.this.workspace_id
  client_id     = local.databricks_client_id
  client_secret = local.databricks_client_secret
}
