# main.tf
#
# Environment-driven deployment routing for the shared xcadi EKS cluster.
# This module is designed to run from a single "prod" execution context
# (e.g. the platform UI/pipeline running in the prod account) and deploy
# to whichever target account the caller selects via var.env:
#
#   dev  -> clearlake-dev
#   test -> clearlake-test
#   uat  -> clearlake-test
#   prod -> clearlake-prod
#
# The default (unaliased) "aws" provider below assumes the env-target
# backend IRSA role unless Terraform is already running as that exact
# role in that exact account, in which case it reuses the current
# session. This mirrors the pattern used in dip_databricks_resources.

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

# Provider tied to whatever account/role Terraform is actually executing
# as (e.g. the prod pipeline identity). Used only to detect the execution
# context so we know whether an assume_role hop is required.
provider "aws" {
  alias  = "execution"
  region = var.region
}

# Default provider used by every resource in this module. Assumes the
# env-target backend IRSA role when the execution identity isn't already
# that role.
provider "aws" {
  region = var.region

  dynamic "assume_role" {
    for_each = local.use_assume_role_for_target ? [1] : []
    content {
      role_arn     = local.target_backend_irsa_role_arn
      session_name = "xcadi-eks-${local.selected_env}"
    }
  }
}

data "aws_caller_identity" "execution" {
  provider = aws.execution
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  selected_env                  = one(var.env)
  selected_aws_account_label    = lookup(var.aws_account_label_by_env, local.selected_env, "")
  selected_account_number       = lookup(var.aws_account_number_by_env, local.selected_env, "")
  target_backend_irsa_role_name = lookup(var.backend_irsa_role_name_by_env, local.selected_env, "prod-xcadi-backend-irsa-role")
  target_backend_irsa_role_arn  = "arn:aws:iam::${local.selected_account_number}:role/${local.target_backend_irsa_role_name}"

  execution_account_number = data.aws_caller_identity.execution.account_id
  execution_principal_arn  = data.aws_caller_identity.execution.arn

  # True when Terraform is already executing as the exact target backend
  # IRSA role in the target account (no assume_role hop needed).
  execution_is_target_backend_irsa_role = local.execution_account_number == local.selected_account_number && (
    local.execution_principal_arn == local.target_backend_irsa_role_arn ||
    can(regex("^arn:aws:sts::${local.selected_account_number}:assumed-role/${local.target_backend_irsa_role_name}/.+$", local.execution_principal_arn))
  )

  use_assume_role_for_target = !local.execution_is_target_backend_irsa_role

  # ------------------------------------------------------------------
  # DevOps/KMS admin access - common across dev/test/uat/prod, derived
  # from the selected env unless explicitly overridden by the caller.
  # ------------------------------------------------------------------
  effective_devops_role_arn = coalesce(
    var.devops_role_arn,
    lookup(var.devops_role_arn_by_env, local.selected_env, null)
  )

  effective_kms_key_administrators = (
    length(var.kms_key_administrators) > 0
    ? var.kms_key_administrators
    : lookup(var.kms_key_administrators_by_env, local.selected_env, [])
  )
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

  assert {
    condition     = local.effective_devops_role_arn != null && trimspace(local.effective_devops_role_arn) != ""
    error_message = "No devops role ARN resolved for env '${local.selected_env}'. Set devops_role_arn or add a mapping to devops_role_arn_by_env."
  }
}
