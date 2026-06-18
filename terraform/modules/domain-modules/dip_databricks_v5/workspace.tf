# workspace.tf

locals {
  zscaler_cidr_blocks = ["172.29.0.0/16", "172.19.0.0/16"]
}

resource "aws_security_group" "databricks" {
  count       = var.enable_workspace_security_group && !local.create_sg_in_databricks_account ? 1 : 0
  name_prefix = "${local.selected_env}-dip-${local.normalized_domain_name}${var.team_name != "" ? "-${var.team_name}" : ""}-databricks-workspace"
  vpc_id      = var.vpc_id
  description = "Security group for Databricks workspace"

  dynamic "ingress" {
    for_each = length(concat(var.vpc_cidr, local.zscaler_cidr_blocks)) > 0 ? [1] : []
    content {
      cidr_blocks = concat(var.vpc_cidr, local.zscaler_cidr_blocks)
      description = "Allow all traffic from VPC and Zscaler CIDR blocks"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
    }
  }

  ingress {
    description = "Node to node access"
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    self        = true
  }

  dynamic "ingress" {
    for_each = length(var.workspace_prefix_list_ids) > 0 ? [1] : []
    content {
      prefix_list_ids = var.workspace_prefix_list_ids
      description     = "Allow traffic from configured prefix lists"
      from_port       = 0
      to_port         = 0
      protocol        = "-1"
    }
  }

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all traffic outbound"
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
  }

  tags = local.effective_tags
}

resource "aws_security_group" "databricks_in_databricks_account" {
  provider    = aws.databricks_account
  count       = var.enable_workspace_security_group && local.create_sg_in_databricks_account ? 1 : 0
  name_prefix = "${local.selected_env}-dip-${local.normalized_domain_name}${var.team_name != "" ? "-${var.team_name}" : ""}-databricks-workspace"
  vpc_id      = var.vpc_id
  description = "Security group for Databricks workspace"

  dynamic "ingress" {
    for_each = length(concat(var.vpc_cidr, local.zscaler_cidr_blocks)) > 0 ? [1] : []
    content {
      cidr_blocks = concat(var.vpc_cidr, local.zscaler_cidr_blocks)
      description = "Allow all traffic from VPC and Zscaler CIDR blocks"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
    }
  }

  ingress {
    description = "Node to node access"
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    self        = true
  }

  dynamic "ingress" {
    for_each = length(var.workspace_prefix_list_ids) > 0 ? [1] : []
    content {
      prefix_list_ids = var.workspace_prefix_list_ids
      description     = "Allow traffic from configured prefix lists"
      from_port       = 0
      to_port         = 0
      protocol        = "-1"
    }
  }

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all traffic outbound"
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
  }

  tags = local.effective_tags
}

resource "random_string" "network_name_suffix" {
  length  = 6
  special = false
  upper   = false
  lower   = true
  numeric = true
}

resource "databricks_mws_networks" "this" {
  provider     = databricks.mws
  account_id   = local.databricks_account_id
  network_name = "dip-dbx-${local.selected_env}-${local.normalized_domain_name}${var.team_name != "" ? "-${var.team_name}" : ""}-${random_string.network_name_suffix.result}-network"
  security_group_ids = var.enable_workspace_security_group ? (
    local.create_sg_in_databricks_account ? [aws_security_group.databricks_in_databricks_account[0].id] : [aws_security_group.databricks[0].id]
  ) : var.security_group_ids
  subnet_ids = var.subnet_ids
  vpc_id     = var.vpc_id
}

resource "databricks_metastore_assignment" "this" {
  depends_on = [
    databricks_mws_workspaces.this
  ]
  provider     = databricks.workspace
  workspace_id = databricks_mws_workspaces.this.workspace_id
  metastore_id = var.metastore_id
  #default_catalog_name = "main"
}

resource "databricks_enhanced_security_monitoring_workspace_setting" "this" {
  provider = databricks.workspace
  enhanced_security_monitoring_workspace {
    # This directly toggles the workspace setting on/off
    is_enabled = var.enable_esm
  }
}

resource "databricks_restrict_workspace_admins_setting" "restrict_admins" {
  provider = databricks.workspace
  restrict_workspace_admins {
    status = "RESTRICT_TOKENS_AND_JOB_RUN_AS"
  }
}

locals {
  repo_urls = [
    for r in var.github_repo : "${var.github_org_url}/${split("@", split(":", r)[0])[0]}"
  ]
}

resource "databricks_workspace_conf" "git_allowlist_config" {
  provider = databricks.workspace
  custom_config = {
    "enableProjectsAllowList"              = "true"
    "projectsAllowList"                    = join(",", local.repo_urls)
    "projectsAllowListPermissions"         = "ALLOWLISTED_CLONE_COMMIT_PUSH"
    "enableVerboseAuditLogs"               = "true"
    "enableDatabricksAutologgingAdminConf" = "true"
    "enableResultsDownloading"             = "false"
    "enableExportNotebook"                 = "false"
    "mlflowRunArtifactDownloadEnabled"     = "false"
    "enableNotebookTableClipboard"         = "false"
    "enableFileStoreEndpoint"              = "false"
    "enableIpAccessLists"                  = "false"
    "maxTokenLifetimeDays"                 = "90"
  }
}

# resource "databricks_ip_access_list" "allowed_ip_list" {
#   provider     = databricks.workspace
#   label        = "Network Allow List"
#   list_type    = "ALLOW"
#   ip_addresses = var.allowed_ip_addresses
#   depends_on   = [databricks_workspace_conf.git_allowlist_config]
# }

# mwa_Credentials.tf

resource "random_string" "credential_name_suffix" {
  length  = 6
  special = false
  upper   = false
  numeric = true
}

# MWS credentials (cross-account IAM role) for workspace creation
resource "databricks_mws_credentials" "this" {
  provider         = databricks.mws
  credentials_name = "dip-dbx-${local.selected_env}-${local.normalized_domain_name}${var.team_name != "" ? "-${var.team_name}" : ""}-${random_string.credential_name_suffix.result}-credentials"
  role_arn         = local.effective_cross_account_role_arn
}

# MWS storage configuration (root S3 bucket)
resource "random_string" "storage_name_suffix" {
  length  = 6
  special = false
  upper   = false
  numeric = true
}

resource "databricks_mws_storage_configurations" "this" {
  provider                   = databricks.mws
  account_id                 = local.databricks_account_id
  storage_configuration_name = "${var.prefix}-storage"
  bucket_name                = local.effective_root_storage_bucket
}

resource "databricks_mws_workspaces" "this" {
  provider                 = databricks.mws
  account_id               = local.databricks_account_id
  aws_region               = var.aws_region
  workspace_name           = "dip-dbx-${local.selected_env}-${local.normalized_domain_name}${var.team_name != "" ? "-${var.team_name}" : ""}"
  credentials_id           = databricks_mws_credentials.this.credentials_id
  storage_configuration_id = databricks_mws_storage_configurations.this.storage_configuration_id
  network_id               = databricks_mws_networks.this.network_id

  custom_tags              = local.effective_tags

  lifecycle {
    ignore_changes = [
      workspace_name
    ]
  }
}
