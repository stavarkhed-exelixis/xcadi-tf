variable "databricks_credentials_secret_name" {
  description = "Optional override for Databricks credentials secret name/ARN. If null, module derives databricks/dip-<env>/credentials from var.env."
  type        = string
  default     = null
  nullable    = true
}

variable "prefix" {
  description = "Prefix for resource naming"
  type        = string
  default     = "dip"
}

variable "cross_account_role_arn" {
  description = "Optional override for AWS IAM workspace cross-account role ARN. If null, module derives role ARN from var.env and cross_account_role_account_id."
  type        = string
  default     = null
  nullable    = true
}

variable "cross_account_role_account_id" {
  description = "AWS account ID that owns the Databricks workspace cross-account role (Databricks management account)."
  type        = string
  default     = "735877683719"
}

variable "root_storage_bucket" {
  description = "Optional override for root storage bucket. If null, module derives bucket name from var.env, aws_region, and environment_account_ids."
  type        = string
  default     = null
  nullable    = true
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
  default     = "vpc-02b08032b2dbdca8e"
}

variable "subnet_ids" {
  description = "List of subnet IDs (minimum 2 required)"
  type        = list(string)
  default     = ["subnet-005f25a47d7ab2e03", "subnet-09e15d5b612393879"]
}

variable "security_group_ids" {
  description = "List of security group IDs (minimum 1 required)"
  type        = list(string)
  default = [
    "sg-08d7fe57f59c1ffa9"
  ]
}

variable "aws_region" {
  description = "AWS region for the workspace"
  type        = string
  default     = "us-west-2"
}

variable "domain_name" {
  description = "Name for the Databricks workspace"
  type        = string
}

variable "team_name" {
  description = "Name for the Databricks workspace"
  type        = string
  default     = ""
}

variable "devops_admins_name" {
  type    = string
  default = "OG_DIP_DBricks_DevOps_Admin"
}

variable "enable_sql_warehouse" {
  type        = bool
  default     = false
  description = "enable_sql_warehouse"
}

variable "existing_sql_warehouse_id" {
  type        = string
  default     = null
  description = "Optional existing Databricks SQL warehouse ID. When set, module skips warehouse creation and applies permissions to this warehouse."
}

variable "enable_catalog" {
  type        = bool
  default     = false
  description = "enable_catalog"
}

variable "metastore_id" {
  description = "Unity Catalog metastore ID used when creating the catalog"
  type        = string
  default     = "819fd80f-024b-4d0f-8141-a136ba322991"
}

variable "catalog_name" {
  description = "Catalog name to create when enable_catalog is true"
  type        = string
  default     = ""
}

variable "catalog_comment" {
  description = "Optional comment for the created catalog"
  type        = string
  default     = ""
}

variable "force_destroy" {
  description = "Whether to force destroy catalog objects on delete"
  type        = bool
  default     = false
}

variable "env" {
  description = "Deployment environment as a single-item list (UI-friendly). Allowed values: dev, test, uat, prod."
  type        = list(string)

  validation {
    condition     = length(var.env) == 1
    error_message = "env must contain exactly one value."
  }

  validation {
    condition = alltrue([
      for e in var.env : contains(["dev", "test", "uat", "prod"], e)
    ])
    error_message = "Invalid environment. Allowed values are dev, test, uat, prod."
  }
}

variable "environment_account_ids" {
  description = "AWS data account IDs by environment used to derive env-specific bucket and external-catalog role defaults when explicit overrides are not provided."
  type        = map(string)
  default = {
    dev  = "441447966705"
    test = "154916814622"
    uat  = "154916814622"
    prod = "754095075756"
  }

  validation {
    condition = alltrue([
      for k in ["dev", "test", "uat", "prod"] : contains(keys(var.environment_account_ids), k)
    ])
    error_message = "environment_account_ids must include keys for dev, test, uat, and prod."
  }
}

variable "compliance_standards" {
  description = "List of compliance standards for workspace"
  type        = list(string)
  default     = ["NONE"]

  validation {
    condition = alltrue([
      for v in var.compliance_standards :
      contains([
        "NONE",
        "HIPAA",
        "PCI_DSS",
        "FEDRAMP_MODERATE",
        "GERMANY_C5",
        "GERMANY_TISAX",
        "HITRUST",
        "ISMAP"
      ], v)
    ])
    error_message = "Invalid compliance standard selected."
  }
}

variable "workspace_users" {
  description = "Set of AD usernames/emails to grant Databricks workspace USER access"
  type        = set(string)
  default     = []
}

variable "tags" {
  description = "Optional tags to add to created resources"
  type        = map(string)
  default     = {}
}

variable "admins_name" {
  description = "Databricks account group name for domain admins"
  type        = string
  default     = "Domain-Admins"
}

variable "developers_name" {
  description = "Databricks account group name for domain developers"
  type        = string
  default     = "Domain Developers"
}

variable "consumers_name" {
  description = "Databricks account group name for domain consumers"
  type        = string
  default     = "Domain Consumers"
}

variable "external_catalog_iam_role_arn" {
  description = "IAM role ARN for Databricks UC/service credential access"
  type        = string
  default     = ""
}

variable "external_catalog_iam_role_arns" {
  description = "Optional IAM role ARNs for Databricks UC/service credential access by environment. If provided for the selected env, it takes precedence over derived ARN."
  type        = map(string)
  default     = {}
}

variable "external_catalog_iam_role_name_suffix" {
  description = "Role name suffix used to derive external catalog IAM role ARN when explicit ARNs are not provided."
  type        = string
  default     = "dbx-ext-catalog-role"
}

variable "enable_external_catalog_iam_role" {
  description = "Create external catalog IAM role and inline policy in this module."
  type        = bool
  default     = true
}

variable "unity_catalog_role_arn" {
  description = "Unity Catalog IAM role ARN used in trust policy for external catalog IAM role. Required when enable_external_catalog_iam_role is true."
  type        = string
  default     = "arn:aws:iam::414351767826:role/unity-catalog-prod-UCMasterRole-14S5ZJVKOTYTL"
}

variable "external_catalog_is_custom_path" {
  description = "Whether to use custom bucket path for external catalog IAM role policy scope."
  type        = bool
  default     = false
}

variable "external_catalog_custom_bucket_path" {
  description = "Custom S3 prefix path used when external_catalog_is_custom_path is true."
  type        = string
  default     = ""
}

variable "external_catalog_s3_path_prefixes" {
  description = "List of dynamic S3 prefixes for external catalog IAM role policy scope. If empty, falls back to domain/team or custom path."
  type        = list(string)
  default     = []
}

variable "enable_external_catalog_s3_prefix_creation" {
  description = "Create bootstrap S3 prefixes for raw/staging/analytics buckets."
  type        = bool
  default     = true
}

variable "raw_external_catalog_s3_url" {
  description = "RAW S3 URL path without scheme (bucket/path)"
  type        = string
  default     = ""
}

variable "staging_external_catalog_s3_url" {
  description = "STAGING S3 URL path without scheme (bucket/path)"
  type        = string
  default     = ""
}

variable "analytics_external_catalog_s3_url" {
  description = "ANALYTICS S3 URL path without scheme (bucket/path)"
  type        = string
  default     = ""
}

variable "additional_external_location_raw_bucket" {
  description = "Additional RAW bucket for dynamic external locations"
  type        = string
  default     = ""
}

variable "additional_external_location_staging_bucket" {
  description = "Additional STAGING bucket for dynamic external locations"
  type        = string
  default     = ""
}

variable "additional_external_location_analytics_bucket" {
  description = "Additional ANALYTICS bucket for dynamic external locations"
  type        = string
  default     = ""
}

variable "raw_bucket" {
  description = "RAW bucket by environment"
  type        = map(string)
  default = {
    dev  = "exelixis-clearlake-daplex-dev-us-west-2-441447966705-raw"
    test = "exelixis-clearlake-daplex-test-us-west-2-154916814622-raw"
    uat  = "exelixis-clearlake-daplex-uat-us-west-2-154916814622-raw"
    prod = "exelixis-clearlake-daplex-prod-us-west-2-754095075756-raw"
  }

  validation {
    condition = alltrue([
      for k in ["dev", "test", "uat", "prod"] : contains(keys(var.raw_bucket), k)
    ])
    error_message = "raw_bucket must include keys for dev, test, uat, and prod."
  }
}

variable "staging_bucket" {
  description = "STAGING bucket by environment"
  type        = map(string)
  default = {
    dev  = "exelixis-clearlake-daplex-dev-us-west-2-441447966705-staging"
    test = "exelixis-clearlake-daplex-test-us-west-2-154916814622-staging"
    uat  = "exelixis-clearlake-daplex-uat-us-west-2-154916814622-staging"
    prod = "exelixis-clearlake-daplex-prod-us-west-2-754095075756-staging"
  }

  validation {
    condition = alltrue([
      for k in ["dev", "test", "uat", "prod"] : contains(keys(var.staging_bucket), k)
    ])
    error_message = "staging_bucket must include keys for dev, test, uat, and prod."
  }
}

variable "analytics_bucket" {
  description = "ANALYTICS bucket by environment"
  type        = map(string)
  default = {
    dev  = "exelixis-clearlake-daplex-dev-us-west-2-441447966705-analytics"
    test = "exelixis-clearlake-daplex-test-us-west-2-154916814622-analytics"
    uat  = "exelixis-clearlake-daplex-uat-us-west-2-154916814622-analytics"
    prod = "exelixis-clearlake-daplex-prod-us-west-2-754095075756-analytics"
  }

  validation {
    condition = alltrue([
      for k in ["dev", "test", "uat", "prod"] : contains(keys(var.analytics_bucket), k)
    ])
    error_message = "analytics_bucket must include keys for dev, test, uat, and prod."
  }
}

variable "additional_external_location_path_prefixes" {
  description = "List of dynamic S3 prefixes for additional external locations"
  type        = list(string)
  default     = []
}

variable "additional_uc_external_location_path_prefixes" {
  description = "List of dynamic UC S3 prefixes"
  type        = list(string)
  default     = []
}

variable "spark_version" {
  description = "Spark version for default and job cluster policies"
  type        = string
  default     = "16.4.x-scala2.12"
}

variable "node_type_id" {
  description = "Node type for default and job cluster policies"
  type        = string
  default     = "r5dn.large"
}

variable "auto_termination_minutes" {
  description = "Auto termination minutes for interactive cluster"
  type        = number
  default     = 20
}

variable "num_workers_min" {
  description = "Minimum worker count for autoscaling"
  type        = number
  default     = 1
}

variable "num_workers_max" {
  description = "Maximum worker count for autoscaling"
  type        = number
  default     = 1
}

variable "cluster_access_mode" {
  description = "Access mode for interactive clusters"
  type        = string
  default     = "USER_ISOLATION"
}

variable "job_cluster_access_mode" {
  description = "Access mode for job clusters"
  type        = string
  default     = "SINGLE_USER"
}

variable "aws_spot_mode" {
  description = "AWS spot mode for job clusters"
  type        = string
  default     = "SPOT_WITH_FALLBACK"
}

variable "enable_default_cluster" {
  description = "Create default interactive cluster and policy"
  type        = bool
  default     = false
}

variable "enable_job_cluster_policy" {
  description = "Create job cluster policy"
  type        = bool
  default     = false
}

variable "enable_token_usage_permissions" {
  description = "Create token usage permissions in workspace. Keep false for workspaces where 'tokens' authorization target is unavailable."
  type        = bool
  default     = false
}

variable "git_integration" {
  description = "Enable Git integration service principal and policies"
  type        = bool
  default     = true
}

variable "git_secret_lifetime" {
  description = "Secret lifetime for generated Databricks SP secrets"
  type        = string
  default     = "63072000s"
}

variable "atlan_integration" {
  description = "Enable Atlan integration service principal"
  type        = bool
  default     = false
}

variable "dbt_integration" {
  description = "Enable DBT integration service principal"
  type        = bool
  default     = false
}

variable "spotfire_integration" {
  description = "Enable Spotfire integration service principal"
  type        = bool
  default     = false
}

variable "tableau_integration" {
  description = "Enable Tableau integration service principal"
  type        = bool
  default     = false
}

variable "posit_integration" {
  description = "Enable Posit integration service principal"
  type        = bool
  default     = false
}

variable "sas_integration" {
  description = "Enable SAS integration service principal"
  type        = bool
  default     = false
}

variable "github_issuer_url" {
  description = "GitHub OIDC issuer URL"
  type        = string
  default     = "https://token.actions.githubusercontent.com"
}

variable "github_org_url" {
  description = "GitHub organization URL"
  type        = string
  default     = "https://github.com/exelixis-cpe"
}

variable "github_org_name" {
  description = "GitHub organization name"
  type        = string
  default     = "exelixis-cpe"
}

variable "git_branch_name" {
  description = "GitHub branch for OIDC federation"
  type        = string
  default     = ""
}

variable "github_repo" {
  description = "GitHub repo contexts. Use one chip per entry in the format 'repo@branch'. Also accepts 'repo:branch' or 'repo' (branch falls back to git_branch_name, otherwise 'main')."
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for v in var.github_repo : can(regex("^[A-Za-z0-9_.-]+([@:][A-Za-z0-9._/-]+)?$", trimspace(v)))
    ])
    error_message = "Each github_repo item must be in format 'repo@branch', 'repo:branch', or 'repo' (letters, numbers, ., _, -, / only in branch)."
  }
}

variable "additional_pypi_libraries" {
  description = "Extra PyPI libraries to install on the cluster policies"
  type        = list(object({ package = string }))
  default     = []
}

variable "additional_maven_libraries" {
  description = "Extra Maven libraries to install on the cluster policies"
  type        = list(object({ package = string }))
  default     = []
}

variable "enable_workspace_folder" {
  description = "Create workspace folder and set folder-level permissions"
  type        = bool
  default     = false
}

variable "enable_external_locations" {
  description = "Create non-catalog RAW/STAGING/ANALYTICS external locations"
  type        = bool
  default     = true
}

variable "enable_budget" {
  description = "Create Databricks workspace budget policy"
  type        = bool
  default     = false
}

variable "budget_email_target" {
  description = "Email target for budget alerts"
  type        = string
  default     = ""
}

variable "budget_monthly_threshold_usd" {
  description = "Monthly cumulative spend threshold in USD"
  type        = number
  default     = 500
}
