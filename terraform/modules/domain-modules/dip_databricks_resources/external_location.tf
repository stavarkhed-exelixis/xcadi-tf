locals {
  create_external_locations             = var.enable_external_locations
  derived_external_catalog_iam_role_arn = "arn:aws:iam::${local.env_account_id}:role/${local.selected_env}-${local.normalized_domain_name}${local.normalized_subdomain_name != "" ? "-${local.normalized_subdomain_name}" : ""}-${var.external_catalog_iam_role_name_suffix}"
  effective_external_catalog_iam_role_arn = coalesce(
    trimspace(var.external_catalog_iam_role_arn) != "" ? var.external_catalog_iam_role_arn : null,
    lookup(var.external_catalog_iam_role_arns, local.selected_env, null),
    local.derived_external_catalog_iam_role_arn
  )
  effective_additional_external_location_raw_bucket = coalesce(
    trimspace(var.additional_external_location_raw_bucket) != "" ? var.additional_external_location_raw_bucket : null,
    try(var.raw_buckets_by_account_number[local.selected_account_number][local.selected_env], null),
    var.raw_bucket[local.selected_env]
  )
  effective_additional_external_location_staging_bucket = coalesce(
    trimspace(var.additional_external_location_staging_bucket) != "" ? var.additional_external_location_staging_bucket : null,
    try(var.staging_buckets_by_account_number[local.selected_account_number][local.selected_env], null),
    var.staging_bucket[local.selected_env]
  )
  effective_additional_external_location_analytics_bucket = coalesce(
    trimspace(var.additional_external_location_analytics_bucket) != "" ? var.additional_external_location_analytics_bucket : null,
    try(var.analytics_buckets_by_account_number[local.selected_account_number][local.selected_env], null),
    var.analytics_bucket[local.selected_env]
  )

  # ------------------------------------------------------------------
  # Additional (arbitrary) external locations
  # ------------------------------------------------------------------
  # Parse var.additional_external_locations entries of the form
  # "bucket/path/prefix". Bucket-only entries are rejected by variable
  # validation, so every entry has a non-empty prefix. Trailing or leading
  # slashes and an optional "s3://" scheme prefix are accepted and stripped
  # here so callers can supply either "bucket/prefix", "bucket/prefix/", or
  # "s3://bucket/prefix/".
  additional_external_location_parsed = [
    for entry in var.additional_external_locations : {
      raw    = trim(replace(trimspace(entry), "s3://", ""), "/")
      bucket = split("/", trim(replace(trimspace(entry), "s3://", ""), "/"))[0]
      prefix = trim(join("/", slice(
        split("/", trim(replace(trimspace(entry), "s3://", ""), "/")),
        1,
        length(split("/", trim(replace(trimspace(entry), "s3://", ""), "/")))
      )), "/")
    }
    if trimspace(entry) != ""
  ]

  # Map keyed by a safe, unique key derived from bucket + prefix. Used for
  # for_each on databricks_external_location and aws_s3_object.
  additional_external_locations_map = {
    for item in local.additional_external_location_parsed :
    trim(replace("${item.bucket}-${item.prefix}", "/", "-"), "-") => item
  }

  # Distinct set of additional buckets to expand IAM role scope.
  additional_external_location_buckets = distinct([
    for item in local.additional_external_location_parsed : item.bucket
  ])

  # Object-level ARNs for the IAM policy: scoped strictly to the supplied
  # "bucket/prefix" (never the whole bucket).
  additional_external_location_object_arns = flatten([
    for item in local.additional_external_location_parsed : [
      "arn:aws:s3:::${item.bucket}/${item.prefix}/*",
      "arn:aws:s3:::${item.bucket}/${item.prefix}",
    ]
  ])

  # Bootstrap folder placeholder objects for every parsed entry.
  additional_external_location_bootstrap_objects = {
    for key, item in local.additional_external_locations_map :
    key => {
      bucket = item.bucket
      key    = "${item.prefix}/"
    }
  }
}

resource "databricks_storage_credential" "dbx_storage_credential" {
  count    = local.create_external_locations ? 1 : 0
  provider = databricks.workspace
  depends_on = [
    databricks_mws_workspaces.this,
    databricks_metastore_assignment.this
  ]

  name    = "${local.selected_env}-${local.normalized_domain_name}${local.normalized_subdomain_name != "" ? "-${local.normalized_subdomain_name}" : ""}-dbx-storage-credential"
  comment = "Credential for ${local.selected_env}_${local.normalized_domain_name}${local.normalized_subdomain_name != "" ? "_${local.normalized_subdomain_name}" : ""} external locations"

  aws_iam_role {
    role_arn = local.create_external_catalog_iam_role ? aws_iam_role.dbx_ext_catalog_role[0].arn : local.effective_external_catalog_iam_role_arn
  }

  isolation_mode = "ISOLATION_MODE_ISOLATED"
  force_update   = true
  force_destroy  = true
}

resource "databricks_credential" "dbx_service_credential" {
  count    = (var.enable_default_cluster || local.create_external_locations) ? 1 : 0
  provider = databricks.workspace
  depends_on = [
    databricks_mws_workspaces.this,
    databricks_metastore_assignment.this
  ]

  name    = "${local.selected_env}-${local.normalized_domain_name}${local.normalized_subdomain_name != "" ? "-${local.normalized_subdomain_name}" : ""}-dbx-service-credential"
  comment = "Service credential for ${local.selected_env}-${local.normalized_domain_name}${local.normalized_subdomain_name != "" ? "-${local.normalized_subdomain_name}" : ""}"
  purpose = "SERVICE"

  aws_iam_role {
    role_arn = local.create_external_catalog_iam_role ? aws_iam_role.dbx_ext_catalog_role[0].arn : local.effective_external_catalog_iam_role_arn
  }

  isolation_mode = "ISOLATION_MODE_ISOLATED"
  force_update   = true
  force_destroy  = true
}

resource "databricks_grants" "dbx_admins_service_creds_grants" {
  count    = (var.enable_default_cluster || local.create_external_locations) ? 1 : 0
  provider = databricks.workspace

  credential = databricks_credential.dbx_service_credential[0].id

  grant {
    principal  = local.workspace_group_display_names["devops_admins"]
    privileges = ["ALL_PRIVILEGES"]
  }

  grant {
    principal  = local.workspace_group_display_names["domain_admins"]
    privileges = ["ACCESS"]
  }

  grant {
    principal  = local.workspace_group_display_names["domain_developers"]
    privileges = ["ACCESS"]
  }

  dynamic "grant" {
    for_each = local.sp_service_credential_grants
    content {
      principal  = grant.key
      privileges = grant.value
    }
  }
}

resource "databricks_external_location" "raw_dbx_external_location" {
  count    = local.create_external_locations && trimspace(var.raw_external_catalog_s3_url) != "" ? 1 : 0
  provider = databricks.workspace

  depends_on = [
    aws_iam_role_policy.dbx_external_catalog_access,
    aws_s3_object.dbx_team_onboarding_folder_creation,
    databricks_mws_workspaces.this,
    databricks_metastore_assignment.this
  ]

  name            = "${local.selected_env}-${local.normalized_domain_name}${local.normalized_subdomain_name != "" ? "-${local.normalized_subdomain_name}" : ""}-dbx-raw-external-location"
  url             = "s3://${var.raw_external_catalog_s3_url}"
  credential_name = databricks_storage_credential.dbx_storage_credential[0].name
  comment         = "RAW external location for ${local.selected_env}_${local.normalized_domain_name}${local.normalized_subdomain_name != "" ? "_${local.normalized_subdomain_name}" : ""} data"
  isolation_mode  = "ISOLATION_MODE_ISOLATED"
  force_destroy   = true
}

resource "databricks_grants" "raw_ext_location_grants" {
  count    = local.create_external_locations && trimspace(var.raw_external_catalog_s3_url) != "" ? 1 : 0
  provider = databricks.workspace

  external_location = databricks_external_location.raw_dbx_external_location[0].name

  grant {
    principal  = local.workspace_group_display_names["devops_admins"]
    privileges = ["ALL_PRIVILEGES", "MANAGE", "CREATE_EXTERNAL_TABLE"]
  }

  grant {
    principal  = local.workspace_group_display_names["domain_admins"]
    privileges = ["READ_FILES", "WRITE_FILES", "BROWSE", "CREATE_EXTERNAL_TABLE"]
  }

  grant {
    principal  = local.workspace_group_display_names["domain_developers"]
    privileges = ["READ_FILES", "WRITE_FILES", "BROWSE"]
  }

  dynamic "grant" {
    for_each = local.sp_external_location_grants
    content {
      principal  = grant.key
      privileges = grant.value
    }
  }
}

resource "databricks_external_location" "additional_raw_dbx_external_location" {
  provider = databricks.workspace
  for_each = local.create_external_locations && trimspace(local.effective_additional_external_location_raw_bucket) != "" ? local.prefixes_safe : {}

  depends_on = [
    aws_iam_role_policy.dbx_external_catalog_access,
    aws_s3_object.dbx_team_onboarding_folder_creation,
    databricks_mws_workspaces.this,
    databricks_metastore_assignment.this
  ]

  name = "${local.selected_env}-${local.normalized_domain_name}${local.team_suffix}-dbx-raw-${each.key}-external-location"

  url             = "s3://${local.effective_additional_external_location_raw_bucket}/${each.value}"
  credential_name = databricks_storage_credential.dbx_storage_credential[0].name
  comment         = "RAW external location for ${local.selected_env}_${local.normalized_domain_name}${local.normalized_subdomain_name != "" ? "_${local.normalized_subdomain_name}" : ""} at prefix '${each.value}'"
  isolation_mode  = "ISOLATION_MODE_ISOLATED"
  force_destroy   = true
}

resource "databricks_grants" "additional_raw_ext_location_grants" {
  provider = databricks.workspace
  for_each = databricks_external_location.additional_raw_dbx_external_location

  external_location = each.value.name

  grant {
    principal  = local.workspace_group_display_names["devops_admins"]
    privileges = ["ALL_PRIVILEGES", "MANAGE", "CREATE_EXTERNAL_TABLE"]
  }

  grant {
    principal  = local.workspace_group_display_names["domain_admins"]
    privileges = ["READ_FILES", "WRITE_FILES", "BROWSE", "CREATE_EXTERNAL_TABLE"]
  }

  grant {
    principal  = local.workspace_group_display_names["domain_developers"]
    privileges = ["READ_FILES", "WRITE_FILES", "BROWSE"]
  }

  dynamic "grant" {
    for_each = local.sp_external_location_grants
    content {
      principal  = grant.key
      privileges = grant.value
    }
  }
}

resource "databricks_external_location" "staging_dbx_external_location" {
  count    = local.create_external_locations && trimspace(var.staging_external_catalog_s3_url) != "" ? 1 : 0
  provider = databricks.workspace

  depends_on = [
    aws_iam_role_policy.dbx_external_catalog_access,
    aws_s3_object.dbx_team_onboarding_folder_creation,
    databricks_mws_workspaces.this,
    databricks_metastore_assignment.this
  ]

  name            = "${local.selected_env}-${local.normalized_domain_name}${local.normalized_subdomain_name != "" ? "-${local.normalized_subdomain_name}" : ""}-dbx-staging-external-location"
  url             = "s3://${var.staging_external_catalog_s3_url}"
  credential_name = databricks_storage_credential.dbx_storage_credential[0].name
  comment         = "STAGING external location for ${local.selected_env}_${local.normalized_domain_name}${local.normalized_subdomain_name != "" ? "_${local.normalized_subdomain_name}" : ""} data"
  isolation_mode  = "ISOLATION_MODE_ISOLATED"
  force_destroy   = true
}

resource "databricks_grants" "staging_ext_location_grants" {
  count    = local.create_external_locations && trimspace(var.staging_external_catalog_s3_url) != "" ? 1 : 0
  provider = databricks.workspace

  external_location = databricks_external_location.staging_dbx_external_location[0].name

  grant {
    principal  = local.workspace_group_display_names["devops_admins"]
    privileges = ["ALL_PRIVILEGES", "MANAGE", "CREATE_EXTERNAL_TABLE"]
  }

  grant {
    principal  = local.workspace_group_display_names["domain_admins"]
    privileges = ["READ_FILES", "WRITE_FILES", "BROWSE", "CREATE_EXTERNAL_TABLE"]
  }

  grant {
    principal  = local.workspace_group_display_names["domain_developers"]
    privileges = ["READ_FILES", "WRITE_FILES", "BROWSE"]
  }

  dynamic "grant" {
    for_each = local.sp_external_location_grants
    content {
      principal  = grant.key
      privileges = grant.value
    }
  }
}

resource "databricks_external_location" "additional_staging_dbx_external_location" {
  provider = databricks.workspace
  for_each = local.create_external_locations && trimspace(local.effective_additional_external_location_staging_bucket) != "" ? local.prefixes_safe : {}

  depends_on = [
    aws_iam_role_policy.dbx_external_catalog_access,
    aws_s3_object.dbx_team_onboarding_folder_creation,
    databricks_mws_workspaces.this,
    databricks_metastore_assignment.this
  ]

  name = "${local.selected_env}-${local.normalized_domain_name}${local.team_suffix}-dbx-staging-${each.key}-external-location"

  url             = "s3://${local.effective_additional_external_location_staging_bucket}/${each.value}"
  credential_name = databricks_storage_credential.dbx_storage_credential[0].name
  comment         = "STAGING external location for ${local.selected_env}_${local.normalized_domain_name}${local.normalized_subdomain_name != "" ? "_${local.normalized_subdomain_name}" : ""} at prefix '${each.value}'"
  isolation_mode  = "ISOLATION_MODE_ISOLATED"
  force_destroy   = true
}

resource "databricks_grants" "additional_staging_ext_location_grants" {
  provider = databricks.workspace
  for_each = databricks_external_location.additional_staging_dbx_external_location

  external_location = each.value.name

  grant {
    principal  = local.workspace_group_display_names["devops_admins"]
    privileges = ["ALL_PRIVILEGES", "MANAGE", "CREATE_EXTERNAL_TABLE"]
  }

  grant {
    principal  = local.workspace_group_display_names["domain_admins"]
    privileges = ["READ_FILES", "WRITE_FILES", "BROWSE", "CREATE_EXTERNAL_TABLE"]
  }

  grant {
    principal  = local.workspace_group_display_names["domain_developers"]
    privileges = ["READ_FILES", "WRITE_FILES", "BROWSE"]
  }

  dynamic "grant" {
    for_each = local.sp_external_location_grants
    content {
      principal  = grant.key
      privileges = grant.value
    }
  }
}

resource "databricks_external_location" "analytics_dbx_external_location" {
  count    = local.create_external_locations && trimspace(var.analytics_external_catalog_s3_url) != "" ? 1 : 0
  provider = databricks.workspace

  depends_on = [
    aws_iam_role_policy.dbx_external_catalog_access,
    aws_s3_object.dbx_team_onboarding_folder_creation,
    databricks_mws_workspaces.this,
    databricks_metastore_assignment.this
  ]

  name            = "${local.selected_env}-${local.normalized_domain_name}${local.normalized_subdomain_name != "" ? "-${local.normalized_subdomain_name}" : ""}-dbx-analytics-external-location"
  url             = "s3://${var.analytics_external_catalog_s3_url}"
  credential_name = databricks_storage_credential.dbx_storage_credential[0].name
  comment         = "ANALYTICS external location for ${local.selected_env}_${local.normalized_domain_name}${local.normalized_subdomain_name != "" ? "_${local.normalized_subdomain_name}" : ""} data"
  isolation_mode  = "ISOLATION_MODE_ISOLATED"
  force_destroy   = true
}

resource "databricks_grants" "analytics_ext_location_grants" {
  count    = local.create_external_locations && trimspace(var.analytics_external_catalog_s3_url) != "" ? 1 : 0
  provider = databricks.workspace

  external_location = databricks_external_location.analytics_dbx_external_location[0].name

  grant {
    principal  = local.workspace_group_display_names["devops_admins"]
    privileges = ["ALL_PRIVILEGES", "MANAGE", "CREATE_EXTERNAL_TABLE"]
  }

  grant {
    principal  = local.workspace_group_display_names["domain_admins"]
    privileges = ["READ_FILES", "WRITE_FILES", "BROWSE", "CREATE_EXTERNAL_TABLE"]
  }

  grant {
    principal  = local.workspace_group_display_names["domain_developers"]
    privileges = ["READ_FILES", "WRITE_FILES", "BROWSE"]
  }

  dynamic "grant" {
    for_each = local.sp_external_location_grants
    content {
      principal  = grant.key
      privileges = grant.value
    }
  }
}

resource "databricks_external_location" "additional_analytics_dbx_external_location" {
  provider = databricks.workspace
  for_each = local.create_external_locations && trimspace(local.effective_additional_external_location_analytics_bucket) != "" ? local.prefixes_safe : {}

  depends_on = [
    aws_iam_role_policy.dbx_external_catalog_access,
    aws_s3_object.dbx_team_onboarding_folder_creation,
    databricks_mws_workspaces.this,
    databricks_metastore_assignment.this
  ]

  name = "${local.selected_env}-${local.normalized_domain_name}${local.team_suffix}-dbx-analytics-${each.key}-external-location"

  url             = "s3://${local.effective_additional_external_location_analytics_bucket}/${each.value}"
  credential_name = databricks_storage_credential.dbx_storage_credential[0].name
  comment         = "ANALYTICS external location for ${local.selected_env}_${local.normalized_domain_name}${local.normalized_subdomain_name != "" ? "_${local.normalized_subdomain_name}" : ""} at prefix '${each.value}'"
  isolation_mode  = "ISOLATION_MODE_ISOLATED"
  force_destroy   = true
}

resource "databricks_grants" "additional_analytics_ext_location_grants" {
  provider = databricks.workspace
  for_each = databricks_external_location.additional_analytics_dbx_external_location

  external_location = each.value.name

  grant {
    principal  = local.workspace_group_display_names["devops_admins"]
    privileges = ["ALL_PRIVILEGES", "MANAGE", "CREATE_EXTERNAL_TABLE"]
  }

  grant {
    principal  = local.workspace_group_display_names["domain_admins"]
    privileges = ["READ_FILES", "WRITE_FILES", "BROWSE", "CREATE_EXTERNAL_TABLE"]
  }

  grant {
    principal  = local.workspace_group_display_names["domain_developers"]
    privileges = ["READ_FILES", "WRITE_FILES", "BROWSE"]
  }

  dynamic "grant" {
    for_each = local.sp_external_location_grants
    content {
      principal  = grant.key
      privileges = grant.value
    }
  }
}

# ----------------------------------------------------------------------
# Additional external locations.
# Driven by var.additional_external_locations (list of "bucket/path/prefix"
# strings). Each entry becomes one external location using the same
# storage credential (and thus the same external catalog IAM role) as the
# default external locations. Buckets are also added to the IAM role
# scope in external_catalog_iam_role.tf.
# ----------------------------------------------------------------------

resource "databricks_external_location" "additional_dbx_external_location" {
  provider = databricks.workspace
  for_each = local.create_external_locations ? local.additional_external_locations_map : {}

  depends_on = [
    aws_iam_role_policy.dbx_external_catalog_access,
    aws_s3_object.dbx_team_onboarding_folder_creation,
    aws_s3_object.dbx_team_onboarding_folder_creation_additional,
    databricks_mws_workspaces.this,
    databricks_metastore_assignment.this
  ]

  name = "${local.selected_env}-${local.normalized_domain_name}${local.team_suffix}-dbx-additional-${each.key}-external-location"

  url             = "s3://${each.value.raw}"
  credential_name = databricks_storage_credential.dbx_storage_credential[0].name
  comment         = "Additional external location for ${local.selected_env}_${local.normalized_domain_name}${local.normalized_subdomain_name != "" ? "_${local.normalized_subdomain_name}" : ""} at 's3://${each.value.raw}'"
  isolation_mode  = "ISOLATION_MODE_ISOLATED"
  force_destroy   = true
}

resource "databricks_grants" "additional_ext_location_grants" {
  provider = databricks.workspace
  for_each = databricks_external_location.additional_dbx_external_location

  external_location = each.value.name

  grant {
    principal  = local.workspace_group_display_names["devops_admins"]
    privileges = ["ALL_PRIVILEGES", "MANAGE", "CREATE_EXTERNAL_TABLE"]
  }

  grant {
    principal  = local.workspace_group_display_names["domain_admins"]
    privileges = ["READ_FILES", "WRITE_FILES", "BROWSE", "CREATE_EXTERNAL_TABLE"]
  }

  grant {
    principal  = local.workspace_group_display_names["domain_developers"]
    privileges = ["READ_FILES", "WRITE_FILES", "BROWSE"]
  }

  dynamic "grant" {
    for_each = local.sp_external_location_grants
    content {
      principal  = grant.key
      privileges = grant.value
    }
  }
}

