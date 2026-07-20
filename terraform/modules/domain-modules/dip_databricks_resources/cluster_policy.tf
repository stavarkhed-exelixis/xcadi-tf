resource "databricks_cluster_policy" "Default_Cluster_Policy" {
  count    = var.enable_default_cluster ? 1 : 0
  provider = databricks.workspace

  name = "${local.selected_env}-${local.normalized_domain_name}${var.team_name != "" ? "-${var.team_name}" : ""}-dbx-default-cluster-policy"

  definition = jsonencode({
    "spark_version" : {
      "type" : "fixed",
      "value" : var.spark_version
    },
    "node_type_id" : {
      "type" : "fixed",
      "value" : var.node_type_id
    },
    "autotermination_minutes" : {
      "type" : "fixed",
      "value" : var.auto_termination_minutes,
      "hidden" : true
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
      "value" : var.cluster_access_mode
    }
  })

  libraries {
    pypi {
      package = "boto3==1.40.58"
    }
  }

  libraries {
    pypi {
      package = "psycopg2==2.9.11"
    }
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
