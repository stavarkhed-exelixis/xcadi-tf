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
  secret_id = var.databricks_credentials_secret_name
}

locals {
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
