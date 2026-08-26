variable "databricks_credentials_secret_name" {
  description = "Optional override for Databricks credentials secret name/ARN. If null, module derives the default secret from var.env, with uat reusing databricks/dip-test/credentials."
  type        = string
  default     = null
  nullable    = true
}

variable "databricks_credentials_env" {
  description = "Optional override for the environment segment used in the default Databricks credentials secret name when databricks_credentials_secret_name is not set. By default, uat reuses test."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.databricks_credentials_env == null ? true : contains(["dev", "test", "uat", "prod", "sbx"], var.databricks_credentials_env)
    error_message = "databricks_credentials_env must be one of: dev, test, uat, prod, sbx."
  }
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
  description = "Optional override for root storage bucket. If null, module derives bucket name from env and cross_account_role_account_id, which is the Databricks/Unity Catalog account."
  type        = string
  default     = null
  nullable    = true
}

variable "aws_account_number_by_env" {
  description = "Target AWS account number keyed by environment. Used to route deployments from a prod UI execution context."
  type        = map(string)
  default = {
    dev  = "441447966705"
    test = "154916814622"
    uat  = "154916814622"
    prod = "754095075756"
    sbx  = "596878271343"
  }

  validation {
    condition = alltrue([
      for account_num in values(var.aws_account_number_by_env) : can(regex("^[0-9]{12}$", account_num))
    ])
    error_message = "aws_account_number_by_env values must be valid 12-digit AWS account numbers."
  }
}

variable "aws_account_label_by_env" {
  description = "Friendly AWS account label keyed by environment for outputs and diagnostics."
  type        = map(string)
  default = {
    dev  = "clearlake-dev"
    test = "clearlake-test"
    uat  = "clearlake-test"
    prod = "clearlake-prod"
    sbx  = "clearlake-sbx"
  }
}

variable "backend_irsa_role_name_by_env" {
  description = "Target backend IRSA role name keyed by environment for cross-account assume-role from prod execution account."
  type        = map(string)
  default = {
    dev  = "dev-xcadi-backend-irsa-role"
    test = "test-xcadi-backend-irsa-role"
    uat  = "test-xcadi-backend-irsa-role"
    prod = "prod-xcadi-backend-irsa-role"
    sbx  = "sbx-xcadi-backend-irsa-role"
  }

  validation {
    condition = alltrue([
      for role_name in values(var.backend_irsa_role_name_by_env) : trimspace(role_name) != ""
    ])
    error_message = "backend_irsa_role_name_by_env values must be non-empty role names."
  }
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

variable "enable_workspace_security_group" {
  description = "Create and attach a module-managed security group for Databricks workspace networking."
  type        = bool
  default     = true
}

variable "create_workspace_security_group_in_databricks_account" {
  description = "When true, create the module-managed workspace security group in the Databricks account (cross_account_role_account_id)."
  type        = bool
  default     = true
}

variable "databricks_account_assume_role_arn" {
  description = "Optional IAM role ARN to assume when creating SG resources in Databricks account. Required when Databricks account differs from execution account and direct credentials cannot access it."
  type        = string
  default     = null
  nullable    = true
}

variable "vpc_cidr" {
  description = "CIDR blocks allowed for VPC-wide ingress to the module-managed Databricks security group."
  type        = list(string)
  default     = ["10.98.200.0/22"]
}

variable "workspace_prefix_list_ids" {
  description = "Optional prefix list IDs allowed ingress to the module-managed Databricks security group."
  type        = list(string)
  default = [
    "pl-0e3949231454f3679",
    "pl-04a3dbacad5e58717",
    "pl-0d97e7f6ef8f25ef9"
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

variable "additional_catalogs" {
  description = "List of additional catalogs to create. Each entry must use the format 'name|description' (pipe-separated). The name (before the pipe) is lowercase alphanumeric with hyphens/underscores — used as the suffix in the catalog name and storage root path. The description (after the pipe) is used as the catalog comment. Example: 'analytics|Analytics domain catalog'"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for entry in var.additional_catalogs :
      can(regex("^[a-z0-9][a-z0-9_-]*\\|.+$", trimspace(entry)))
    ])
    error_message = "Each additional_catalogs entry must be in format 'name|description'. Name must be lowercase alphanumeric with optional hyphens/underscores (e.g. 'analytics|My catalog description')."
  }
}

variable "force_destroy" {
  description = "Whether to force destroy catalog objects on delete"
  type        = bool
  default     = true
}

variable "env" {
  description = "Deployment environment as a single-item list (UI-friendly). Allowed values: dev, test, uat, prod, sbx."
  type        = list(string)

  validation {
    condition     = length(var.env) == 1
    error_message = "env must contain exactly one value."
  }

  validation {
    condition = alltrue([
      for e in var.env : contains(["dev", "test", "uat", "prod", "sbx"], e)
    ])
    error_message = "Invalid environment. Allowed values are dev, test, uat, prod, sbx."
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
        "HIPAA"
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

variable "created_by" {
  description = "Identifier of the person or system that created this workspace (used for tagging and auditing)."
  type        = string
  default     = ""
}

variable "platform" {
  description = "Platform name this workspace belongs to (used for tagging and auditing, e.g. 'databricks', 'xcadi')."
  type        = string
  default     = "xcadi"
}

variable "product_owner" {
  description = "Name or email of the product owner responsible for this workspace."
  type        = string
  default     = ""
}

variable "product_manager" {
  description = "Name or email of the product manager responsible for this workspace."
  type        = string
  default     = ""
}

variable "admins_name" {
  description = "Databricks account group name for domain admins"
  type        = string
  default     = "OG_DIP_DBricks_DATABRICKS_DOMAIN_ADMINS"
}

variable "developers_name" {
  description = "Databricks account group name for domain developers"
  type        = string
  default     = "OG_DIP_DBricks_DATABRICKS_DEVELOPERS"
}

variable "consumers_name" {
  description = "Databricks account group name for domain consumers"
  type        = string
  default     = "OG_DIP_DBricks_DATABRICKS_CONSUMERS"
}

variable "custom_groups" {
  description = "Additional group names (beyond admins/developers/consumers) to assign to the workspace with USER access, and grant CAN_RESTART on the default cluster and CAN_USE on the SQL warehouse."
  type        = list(string)
  default     = []
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

variable "additional_external_locations" {
  description = "Optional list of additional external locations to create in addition to the default RAW/STAGING/ANALYTICS locations. Each entry must be of the form 'bucket/path/prefix' with at least one path segment after the bucket. Trailing slashes and an optional 's3://' scheme prefix are accepted (e.g. 'my-bucket/foo/bar', 'my-bucket/foo/bar/', 's3://my-bucket/foo/bar/'). Bucket-only entries are not allowed. The bucket is automatically appended to the external catalog IAM role scope; permissions are scoped to the given prefix. Reuses the same storage credential."
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for entry in var.additional_external_locations :
      can(regex("^(s3://)?[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]/[^/].*$", trimspace(entry)))
    ])
    error_message = "Each additional_external_locations entry must be in the form 'bucket/path/prefix' (bucket followed by at least one path segment). Bucket-only entries are not permitted. Optional 's3://' scheme and trailing '/' are accepted."
  }
}

variable "raw_bucket" {
  description = "RAW bucket by environment"
  type        = map(string)
  default = {
    dev  = "exelixis-clearlake-daplex-dev-us-west-2-441447966705-raw"
    test = "exelixis-clearlake-daplex-test-us-west-2-154916814622-raw"
    uat  = "exelixis-clearlake-daplex-uat-us-west-2-154916814622-raw"
    prod = "exelixis-clearlake-daplex-prod-us-west-2-754095075756-raw"
    sbx  = "exelixis-clearlake-daplex-dev-us-west-2-596878271343-raw"
  }

  validation {
    condition = alltrue([
      for k in ["dev", "test", "uat", "prod", "sbx"] : contains(keys(var.raw_bucket), k)
    ])
    error_message = "raw_bucket must include keys for dev, test, uat, prod, and sbx."
  }
}

variable "raw_buckets_by_account_number" {
  description = "RAW bucket defaults keyed by account_number, then env."
  type        = map(map(string))
  default = {
    "754095075756" = {
      dev  = "exelixis-clearlake-daplex-dev-us-west-2-754095075756-raw"
      test = "exelixis-clearlake-daplex-test-us-west-2-754095075756-raw"
      uat  = "exelixis-clearlake-daplex-uat-us-west-2-754095075756-raw"
      prod = "exelixis-clearlake-daplex-prod-us-west-2-754095075756-raw"
    }
    "154916814622" = {
      test = "exelixis-clearlake-daplex-test-us-west-2-154916814622-raw"
      uat  = "exelixis-clearlake-daplex-uat-us-west-2-154916814622-raw"
    }
    "596878271343" = {
      sbx = "exelixis-clearlake-daplex-dev-us-west-2-596878271343-raw"
    }
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
    sbx  = "exelixis-clearlake-daplex-dev-us-west-2-596878271343-staging"
  }

  validation {
    condition = alltrue([
      for k in ["dev", "test", "uat", "prod", "sbx"] : contains(keys(var.staging_bucket), k)
    ])
    error_message = "staging_bucket must include keys for dev, test, uat, prod, and sbx."
  }
}

variable "staging_buckets_by_account_number" {
  description = "STAGING bucket defaults keyed by account_number, then env."
  type        = map(map(string))
  default = {
    "754095075756" = {
      dev  = "exelixis-clearlake-daplex-dev-us-west-2-754095075756-staging"
      test = "exelixis-clearlake-daplex-test-us-west-2-754095075756-staging"
      uat  = "exelixis-clearlake-daplex-uat-us-west-2-754095075756-staging"
      prod = "exelixis-clearlake-daplex-prod-us-west-2-754095075756-staging"
    }
    "154916814622" = {
      test = "exelixis-clearlake-daplex-test-us-west-2-154916814622-staging"
      uat  = "exelixis-clearlake-daplex-uat-us-west-2-154916814622-staging"
    }
    "596878271343" = {
      sbx = "exelixis-clearlake-daplex-dev-us-west-2-596878271343-staging"
    }
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
    sbx  = "exelixis-clearlake-daplex-dev-us-west-2-596878271343-analytics"
  }

  validation {
    condition = alltrue([
      for k in ["dev", "test", "uat", "prod", "sbx"] : contains(keys(var.analytics_bucket), k)
    ])
    error_message = "analytics_bucket must include keys for dev, test, uat, prod, and sbx."
  }
}

variable "analytics_buckets_by_account_number" {
  description = "ANALYTICS bucket defaults keyed by account_number, then env."
  type        = map(map(string))
  default = {
    "754095075756" = {
      dev  = "exelixis-clearlake-daplex-dev-us-west-2-754095075756-analytics"
      test = "exelixis-clearlake-daplex-test-us-west-2-754095075756-analytics"
      uat  = "exelixis-clearlake-daplex-uat-us-west-2-754095075756-analytics"
      prod = "exelixis-clearlake-daplex-prod-us-west-2-754095075756-analytics"
    }
    "154916814622" = {
      test = "exelixis-clearlake-daplex-test-us-west-2-154916814622-analytics"
      uat  = "exelixis-clearlake-daplex-uat-us-west-2-154916814622-analytics"
    }
    "596878271343" = {
      sbx = "exelixis-clearlake-daplex-dev-us-west-2-596878271343-analytics"
    }
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
  default     = "18.x-scala2.13"
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
  default     = true
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

variable "powerapps_integration" {
  description = "Enable PowerApps integration service principal"
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
  default     = true
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
  default     = "daplex@exelixis.com"
}

variable "budget_monthly_threshold_usd" {
  description = "Monthly cumulative spend threshold in USD"
  type        = number
  default     = 500
}

variable "create_okta_groups" {
  description = "Create okta  groups"
  type        = bool
  default     = true
}

variable "okta_devops_admins_name" {
  description = "Existing Okta-synced Databricks group name for DevOps admins (used when create_okta_groups=true)."
  type        = string
  default     = ""
}

variable "okta_admins_name" {
  description = "Existing Okta-synced Databricks group name for domain admins (used when create_okta_groups=true)."
  type        = string
  default     = ""
}

variable "okta_developers_name" {
  description = "Existing Okta-synced Databricks group name for domain developers (used when create_okta_groups=true)."
  type        = string
  default     = ""
}

variable "okta_consumers_name" {
  description = "Existing Okta-synced Databricks group name for domain consumers (used when create_okta_groups=true)."
  type        = string
  default     = ""
}

variable "allowed_ip_addresses" {
  description = "Repository names within the org"
  type        = list(string)
  default = [
    "65.209.203.253/32",
    "65.209.203.228/32",

    # Additional New Zscaler Exelixis IPs shared by Param
    "54.203.202.128",
    "44.255.234.127",
    "35.170.16.17",
    "54.80.27.113",

    #SIPA IPs
    "159.254.240.115",
    "159.254.240.83",
    "137.31.49.26",
    "137.31.49.58",

    "65.209.203.253", #Old IP, we still need it.

    #posit IPs (EKS hosted)
    #clearlake dev eks
    "54.190.115.140",
    "54.186.223.75",
    "44.236.33.2",
    #clearlake test eks  
    "44.230.29.174",
    #clearlake prod eks and Self hosted github runner NAT gateway IPs
    "44.226.245.197",

    #Tableau IPs
    "100.21.82.237",    #PRODTABLEAUSER
    "44.233.200.109",   #tbswinprd02 and tbswinprd03
    "52.37.162.125",    #tbswinval01 and Spotfire VAL (gxp-tst) (AP1, AP2, WB1, WB2)
    "44.228.70.8",      #tbswindev01
    "155.226.128.0/21", #Tableau cloud us-west-2 (IP reference document: https://help.tableau.com/current/pro/desktop/en-us/publish_tableau_online_ip_authorization.htm)

    #Spotfire IPs
    #Spotfire DEV (gxp-dev)
    "54.149.21.105", #AP1, AP2, WB1, WB2

    #Spotfire PRD (gxp-prd)
    "44.229.237.209", #AP1, AP2, WB1, WB2

    #SAS IPs
    "52.89.126.153",  #saslxdev02
    "44.232.235.148", #saslxval02
    "18.236.35.220",  #saslxprd02

    "44.250.94.210", #AI portal dev application

    #Atlan IPs
    "52.12.143.119",
    "34.214.58.3",

    "52.11.164.200",
    #"135.232.177.183", #Github runner

    "34.214.50.116", #Databricks NAT gateway IP address

    "35.160.252.116", #Atlantis Egress IP
  ]
}

variable "enable_esm" {
  description = "Enable Databricks Enhanced Security Monitoring for this workspace."
  type        = bool
  default     = false
}

variable "enable_ip_access_lists" {
  description = "Enable Databricks IP access lists workspace setting."
  type        = bool
  default     = false
}

variable "enable_genie_space" {
  description = "Enable Databricks Genie Space for this workspace."
  type        = bool
  default     = false
}

variable "enable_databricks_sandbox" {
  description = "Enable Databricks Sandbox preview for this workspace when databricks_sandbox_setting_name is set."
  type        = bool
  default     = false
}

variable "databricks_sandbox_setting_name" {
  description = "Settings V2 name for Databricks Sandbox preview in this workspace (for example, the setting ID shown in workspace previews/metadata)."
  type        = string
  default     = "lakebox"
  nullable    = false
}

variable "additional_trusted_role_arns" {
  description = "Optional list of additional IAM role ARNs that can assume this role (with Databricks external ID condition)."
  type        = list(string)
  default     = []
}

variable "additional_assumable_role_arns" {
  description = "Optional list of additional IAM role ARNs that this role is allowed to assume."
  type        = list(string)
  default     = []
}