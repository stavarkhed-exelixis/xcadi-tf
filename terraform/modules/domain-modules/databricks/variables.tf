variable "databricks_credentials_secret_name" {
  description = "Name (or ARN) of the AWS Secrets Manager secret holding Databricks credentials. The secret value must be a JSON object with keys: client_id, client_secret, account_id."
  type        = string
  default     = "databricks/dip-dev/credentials"
}

variable "databricks_cross_account_role_arn" {
  description = "AWS IAM Role ARN for Databricks cross-account access (MWS credentials)."
  type        = string
  default     = "arn:aws:iam::735877683719:role/exelixis-dip-dev-databricks-cross-account-role"
}

variable "prefix" {
  description = "Prefix for resource naming"
  type        = string
  default     = "dip"
}

variable "cross_account_role_arn" {
  description = "AWS IAM role ARN for cross-account access"
  type        = string
  default     = "arn:aws:iam::735877683719:role/exelixis-dip-dev-databricks-cross-account-role"
}

variable "root_storage_bucket" {
  description = "S3 bucket name for root storage"
  type        = string
  default     = "exelixis-dip-dev-us-west-2-735877683719-dbx-storage"
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

variable "workspace_name" {
  description = "Name for the Databricks workspace"
  type        = string
}

variable "team_name" {
  description = "Name for the Databricks workspace"
  type        = string
}


variable "compute_mode" {
  type    = string
  default = null
}

variable "devops_admins_name" {
  type    = string
  default = "OG_DIP_DBricks_DevOps_Admin"
}

variable "cred_name" {
  description = "Prefix for resource naming"
  type        = string
  default     = "dip-secret-dev"
}

variable "enable_sql_warehouse" {
  type        = bool
  default     = false
  description = "enable_sql_warehouse"
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
  description = "The environment for which this account will be used."
  type        = string
  default     = "dev"
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
