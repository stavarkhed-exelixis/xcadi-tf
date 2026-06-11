resource "databricks_cluster_policy" "job_cluster_policy" {
  count    = var.enable_job_cluster_policy ? 1 : 0
  provider = databricks.workspace

  name             = "${local.selected_env}-${local.normalized_domain_name}${var.team_name != "" ? "-${var.team_name}" : ""}-dbx-job-cluster-policy"
  policy_family_id = "job-cluster"

  description = "Job-only cluster policy with guardrails and access mode ${var.job_cluster_access_mode}."

  policy_family_definition_overrides = jsonencode({
    "spark_version" : {
      "type" : "fixed",
      "value" : var.spark_version
    },
    "node_type_id" : {
      "type" : "fixed",
      "value" : var.node_type_id
    },
    "autoscale.min_workers" : {
      "type" : "fixed",
      "value" : var.num_workers_min
    },
    "autoscale.max_workers" : {
      "type" : "range",
      "minValue" : var.num_workers_min,
      "maxValue" : var.num_workers_max
    },
    "data_security_mode" : {
      "type" : "fixed",
      "value" : var.job_cluster_access_mode
    },
    "runtime_engine" : {
      "type" : "fixed",
      "value" : "PHOTON",
      "hidden" : true
    },
    "instance_pool_id" : {
      "type" : "forbidden",
      "hidden" : true
    },
    "aws_attributes.availability" : {
      "type" : "fixed",
      "value" : var.aws_spot_mode
    }
  })

  libraries {
    pypi { package = "boto3==1.40.58" }
  }

  libraries {
    pypi { package = "psycopg2==2.9.11" }
  }

  dynamic "libraries" {
    for_each = var.additional_pypi_libraries
    content {
      pypi {
        package = libraries.value.package
      }
    }
  }

  dynamic "libraries" {
    for_each = var.additional_maven_libraries
    content {
      maven {
        coordinates = libraries.value.package
      }
    }
  }
}

resource "databricks_permissions" "policy_use" {
  count             = var.enable_job_cluster_policy ? 1 : 0
  provider          = databricks.workspace
  cluster_policy_id = databricks_cluster_policy.job_cluster_policy[0].id

  access_control {
    group_name       = data.databricks_group.this["domain_admins"].display_name
    permission_level = "CAN_USE"
  }

  dynamic "access_control" {
    for_each = var.git_integration ? [1] : []
    content {
      service_principal_name = databricks_service_principal.svc_git[0].application_id
      permission_level       = "CAN_USE"
    }
  }
}
