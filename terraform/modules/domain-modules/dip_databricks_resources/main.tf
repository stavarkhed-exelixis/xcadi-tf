# provider.tf

terraform {
  required_providers {
    databricks = {
      source = "databricks/databricks"
    }
    aws = {
      source = "hashicorp/aws"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  alias  = "execution"
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
  secret_id = local.effective_databricks_credentials_secret_name
}

data "aws_caller_identity" "execution" {
  provider = aws.execution
}

data "aws_caller_identity" "current" {}

locals {
  selected_env                  = one(var.env)
  selected_aws_account_label    = lookup(var.aws_account_label_by_env, local.selected_env, "")
  selected_account_number       = lookup(var.aws_account_number_by_env, local.selected_env, "")
  target_backend_irsa_role_name = lookup(var.backend_irsa_role_name_by_env, local.selected_env, "prod-xcadi-backend-irsa-role")
  target_backend_irsa_role_arn  = "arn:aws:iam::${local.selected_account_number}:role/${local.target_backend_irsa_role_name}"
  execution_account_number      = data.aws_caller_identity.execution.account_id
  execution_principal_arn       = data.aws_caller_identity.execution.arn
  execution_is_target_backend_irsa_role = local.execution_account_number == local.selected_account_number && (
    local.execution_principal_arn == local.target_backend_irsa_role_arn ||
    can(regex("^arn:aws:sts::${local.selected_account_number}:assumed-role/${local.target_backend_irsa_role_name}/.+$", local.execution_principal_arn))
  )
  use_assume_role_for_target                   = !local.execution_is_target_backend_irsa_role
  effective_cross_account_role_arn             = coalesce(var.cross_account_role_arn, "arn:aws:iam::${var.cross_account_role_account_id}:role/exelixis-dip-${local.selected_env}-databricks-cross-account-role")
  effective_databricks_account_assume_role_arn = coalesce(var.databricks_account_assume_role_arn, local.effective_cross_account_role_arn)
  use_assume_role_for_databricks_account       = local.execution_account_number != var.cross_account_role_account_id || var.databricks_account_assume_role_arn != null
  env_account_id                               = local.selected_account_number
  create_sg_in_databricks_account              = var.create_workspace_security_group_in_databricks_account

  common_tags = merge(
    {
      ucoa           = "1000011007020086"
      product        = "Cloud Platform"
      productmanager =  var.product_manager #"Hiep luong"
      productowner   =  var.product_owner   #"Prashanth Mamidala"
      platform       = var.platform
      created_by      = var.created_by
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
    local.selected_env == "uat" ? "test" : local.selected_env
  )

  effective_databricks_credentials_secret_name = coalesce(var.databricks_credentials_secret_name, "databricks/dip-${local.credential_env}/credentials")
  derived_root_storage_bucket                  = "exelixis-dip-${local.selected_env}-${var.aws_region}-${var.cross_account_role_account_id}-dbx-storage"
  effective_root_storage_bucket                = coalesce(var.root_storage_bucket, local.derived_root_storage_bucket)

  databricks_credentials   = jsondecode(data.aws_secretsmanager_secret_version.databricks.secret_string)
  databricks_client_id     = local.databricks_credentials["client_id"]
  databricks_client_secret = local.databricks_credentials["client_secret"]
  databricks_account_id    = local.databricks_credentials["account_id"]
}

check "selected_env_has_target_account" {
  assert {
    condition     = local.selected_account_number != ""
    error_message = "No target AWS account mapping found for env '${local.selected_env}'. Add it to aws_account_number_by_env."
  }

  assert {
    condition     = trimspace(local.target_backend_irsa_role_name) != ""
    error_message = "No backend IRSA role mapping found for env '${local.selected_env}'. Add it to backend_irsa_role_name_by_env."
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
