# sc.tf

# MWS storage configuration (root S3 bucket)
resource "databricks_mws_storage_configurations" "this" {
  provider                   = databricks.mws
  account_id                 = local.databricks_account_id
  storage_configuration_name = "${var.prefix}-storage"
  bucket_name                = local.effective_root_storage_bucket
}