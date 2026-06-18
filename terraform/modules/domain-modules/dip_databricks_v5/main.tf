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
  alias  = "prod"
  region = var.aws_region
}

provider "aws" {
  region = var.aws_region

  dynamic "assume_role" {
    for_each = local.use_assume_role_for_target ? [1] : []
    content {
      role_arn     = "arn:aws:iam::441447966705:role/${local.selected_env}-xcadi-backend-irsa-role"
      session_name = "xcadi-dbx-${local.selected_env}"
    }
  }
}

# Fetch Databricks credentials from AWS Secrets Manager.
# The secret must be a JSON document with keys:
#   { "client_id": "...", "client_secret": "...", "account_id": "..." }
data "aws_secretsmanager_secret_version" "databricks" {
  provider  = aws.prod
  secret_id = "databricks/dip-dev/credentials"
}

locals {
  selected_env                    = one(var.env)
  selected_account_number         = one(var.account_number)
  selected_account_supported_envs = lookup(var.account_number_supported_environments, local.selected_account_number, [])
  target_backend_irsa_role_name   = lookup(var.backend_irsa_role_name_by_account, local.selected_account_number, "prod-xcadi-backend-irsa-role")
  target_backend_irsa_role_arn    = "arn:aws:iam::${local.selected_account_number}:role/${local.target_backend_irsa_role_name}"
  use_assume_role_for_target      = local.selected_account_number != var.execution_account_number
  env_account_id                  = local.selected_account_number

  credential_env = var.databricks_credentials_env

  effective_databricks_credentials_secret_name = coalesce(var.databricks_credentials_secret_name, "databricks/dip-${local.credential_env}/credentials")
  effective_cross_account_role_arn             = coalesce(var.cross_account_role_arn, "arn:aws:iam::${var.cross_account_role_account_id}:role/exelixis-dip-${local.selected_env}-databricks-cross-account-role")
  derived_root_storage_bucket                  = "exelixis-dip-${local.selected_env}-${var.aws_region}-${var.cross_account_role_account_id}-dbx-storage"
  effective_root_storage_bucket                = coalesce(var.root_storage_bucket, local.derived_root_storage_bucket)

  databricks_credentials   = jsondecode(data.aws_secretsmanager_secret_version.databricks.secret_string)
  databricks_client_id     = local.databricks_credentials["client_id"]
  databricks_client_secret = local.databricks_credentials["client_secret"]
  databricks_account_id    = local.databricks_credentials["account_id"]
}

check "selected_account_number_supports_env" {
  assert {
    condition     = contains(local.selected_account_supported_envs, local.selected_env)
    error_message = "Selected account_number '${local.selected_account_number}' does not support env '${local.selected_env}'. Supported envs: ${join(", ", local.selected_account_supported_envs)}."
  }
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
