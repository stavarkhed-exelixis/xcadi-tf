resource "databricks_cluster" "Default_Cluster" {
  count = var.enable_default_cluster ? 1 : 0
  depends_on = [
    databricks_cluster_policy.Default_Cluster_Policy
  ]
  provider                = databricks.workspace
  cluster_name            = "${local.selected_env}-${local.normalized_domain_name}${var.team_name != "" ? "-${var.team_name}" : ""}-dbx-cluster"
  spark_version           = var.spark_version
  node_type_id            = var.node_type_id
  autotermination_minutes = var.auto_termination_minutes
  data_security_mode      = var.cluster_access_mode

  autoscale {
    min_workers = var.num_workers_min
    max_workers = var.num_workers_max
  }

  spark_env_vars = length(databricks_credential.dbx_service_credential) > 0 ? {
    DATABRICKS_DEFAULT_SERVICE_CREDENTIAL_NAME = databricks_credential.dbx_service_credential[0].name
  } : {}

  policy_id = databricks_cluster_policy.Default_Cluster_Policy[0].id
}
