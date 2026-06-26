# provider.tf

terraform {
  required_providers {
    databricks = {
      source = "databricks/databricks"
      version = 
    }
    aws = {
      source  = "hashicorp/aws"
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
  alias  = "databricks_account"
  region = var.aws_region

  dynamic "assume_role" {
    for_each = local.use_assume_role_for_databricks_account ? [1] : []
    content {
      role_arn     = local.effective_databricks_account_assume_role_arn
      session_name = "xcadi-dbx-sg-${local.selected_env}"
    }
  }
}

provider "aws" {
  region = var.aws_region

  dynamic "assume_role" {
    for_each = local.use_assume_role_for_target ? [1] : []
    content {
      role_arn     = local.target_backend_irsa_role_arn
      session_name = "xcadi-dbx-${local.selected_env}"
    }
  }
}

# Fetch Databricks credentials from AWS Secrets Manager.
# The secret must be a JSON document with keys:
#   { "client_id": "...", "client_secret": "...", "account_id": "..." }
data "aws_secretsmanager_secret_version" "databricks" {
  provider  = aws.prod
  secret_id = local.effective_databricks_credentials_secret_name
}

data "aws_caller_identity" "current" {}

locals {
  selected_env                                 = one(var.env)
  selected_aws_account_label                   = one(var.aws_account)
  selected_account_number                      = lookup(var.aws_account_number_map, local.selected_aws_account_label, "")
  selected_account_supported_envs              = lookup(var.account_number_supported_environments, local.selected_aws_account_label, [])
  target_backend_irsa_role_name                = lookup(var.backend_irsa_role_name_by_account, local.selected_account_number, "prod-xcadi-backend-irsa-role")
  target_backend_irsa_role_arn                 = "arn:aws:iam::${local.selected_account_number}:role/${local.target_backend_irsa_role_name}"
  use_assume_role_for_target                   = local.selected_account_number != var.execution_account_number
  effective_cross_account_role_arn             = coalesce(var.cross_account_role_arn, "arn:aws:iam::${var.cross_account_role_account_id}:role/exelixis-dip-${local.selected_env}-databricks-cross-account-role")
  effective_databricks_account_assume_role_arn = coalesce(var.databricks_account_assume_role_arn, local.effective_cross_account_role_arn)
  use_assume_role_for_databricks_account       = var.execution_account_number != var.cross_account_role_account_id || var.databricks_account_assume_role_arn != null
  env_account_id                               = local.selected_account_number
  create_sg_in_databricks_account              = var.create_workspace_security_group_in_databricks_account

  common_tags = merge(
    {
      ucoa           = "1000011007020086"
      product        = "Cloud Platform"
      productmanager = "Hiep luong"
      productowner   = "Prashanth Mamidala"
      environment    = local.selected_env
      domain         = var.domain_name
    },
    var.team_name != "" ? { subdomain = var.team_name } : {},
    {
      dataproductclassification = "confidential"
      dataproductcompliance     = "NA"
      operations                = "terraform"
      identifier                = "8744520c-0a03-4d4d-8c3d-b1c5cada7b17"
      network                   = "on-prem"
      account_id                = data.aws_caller_identity.current.account_id
    }
  )

  effective_tags = merge(local.common_tags, var.tags)

  credential_env = coalesce(
    var.databricks_credentials_env,
    lookup(var.databricks_credentials_env_by_aws_account, local.selected_aws_account_label, local.selected_env)
  )

  effective_databricks_credentials_secret_name = coalesce(var.databricks_credentials_secret_name, "databricks/dip-${local.credential_env}/credentials")
  derived_root_storage_bucket                  = "exelixis-dip-${local.selected_env}-${var.aws_region}-${var.cross_account_role_account_id}-dbx-storage"
  effective_root_storage_bucket                = coalesce(var.root_storage_bucket, local.derived_root_storage_bucket)

  databricks_credentials   = jsondecode(data.aws_secretsmanager_secret_version.databricks.secret_string)
  databricks_client_id     = local.databricks_credentials["client_id"]
  databricks_client_secret = local.databricks_credentials["client_secret"]
  databricks_account_id    = local.databricks_credentials["account_id"]
}

check "selected_account_number_supports_env" {
  assert {
    condition     = local.selected_account_number != ""
    error_message = "aws_account label '${local.selected_aws_account_label}' was not found in aws_account_number_map. Add it to the mapping."
  }

  assert {
    condition     = contains(local.selected_account_supported_envs, local.selected_env)
    error_message = "Account '${local.selected_aws_account_label}' (${local.selected_account_number}) does not support env '${local.selected_env}'. Supported envs: ${join(", ", local.selected_account_supported_envs)}."
  }
}

check "default_cluster_requires_databricks_account_sg" {
  assert {
    condition     = !var.enable_default_cluster || var.enable_workspace_security_group
    error_message = "enable_default_cluster=true requires enable_workspace_security_group=true so cluster traffic uses a workspace security group."
  }

  assert {
    condition     = !var.enable_default_cluster || var.create_workspace_security_group_in_databricks_account
    error_message = "enable_default_cluster=true requires create_workspace_security_group_in_databricks_account=true so workspace SG is created in Databricks account."
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
