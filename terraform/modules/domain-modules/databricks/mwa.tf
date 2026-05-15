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
  credentials_name = "dip-dbx-${var.env}-${var.domain_name}-${random_string.credential_name_suffix.result}-credentials"
  role_arn         = "arn:aws:iam::735877683719:role/exelixis-dip-dev-databricks-cross-account-role"
}
