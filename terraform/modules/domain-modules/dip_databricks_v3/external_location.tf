locals {
  create_external_locations             = var.enable_external_locations
  derived_external_catalog_iam_role_arn = "arn:aws:iam::${local.env_account_id}:role/${local.selected_env}-${local.normalized_domain_name}${var.team_name != "" ? "-${var.team_name}" : ""}-${var.external_catalog_iam_role_name_suffix}"
  effective_external_catalog_iam_role_arn = coalesce(
    trimspace(var.external_catalog_iam_role_arn) != "" ? var.external_catalog_iam_role_arn : null,
    lookup(var.external_catalog_iam_role_arns, local.selected_env, null),
    local.derived_external_catalog_iam_role_arn
  )
  effective_additional_external_location_raw_bucket = coalesce(
    trimspace(var.additional_external_location_raw_bucket) != "" ? var.additional_external_location_raw_bucket : null,
    var.raw_bucket[local.selected_env]
  )
  effective_additional_external_location_staging_bucket = coalesce(
    trimspace(var.additional_external_location_staging_bucket) != "" ? var.additional_external_location_staging_bucket : null,
    var.staging_bucket[local.selected_env]
  )
  effective_additional_external_location_analytics_bucket = coalesce(
    trimspace(var.additional_external_location_analytics_bucket) != "" ? var.additional_external_location_analytics_bucket : null,
    var.analytics_bucket[local.selected_env]
  )
}

resource "databricks_storage_credential" "dbx_storage_credential" {
  count    = local.create_external_locations ? 1 : 0
  provider = databricks.workspace

  name    = "${local.selected_env}-${local.normalized_domain_name}${var.team_name != "" ? "-${var.team_name}" : ""}-dbx-storage-credential"
  comment = "Credential for ${local.selected_env}_${local.normalized_domain_name}${var.team_name != "" ? "_${var.team_name}" : ""} external locations"

  aws_iam_role {
    role_arn = local.create_external_catalog_iam_role ? aws_iam_role.dbx_ext_catalog_role[0].arn : local.effective_external_catalog_iam_role_arn
  }

  isolation_mode = "ISOLATION_MODE_ISOLATED"
  force_update   = true
}

resource "databricks_credential" "dbx_service_credential" {
  count    = (var.enable_default_cluster || local.create_external_locations) ? 1 : 0
  provider = databricks.workspace

  name    = "${local.selected_env}-${local.normalized_domain_name}${var.team_name != "" ? "-${var.team_name}" : ""}-dbx-service-credential"
  comment = "Service credential for ${local.selected_env}-${local.normalized_domain_name}${var.team_name != "" ? "-${var.team_name}" : ""}"
  purpose = "SERVICE"

  aws_iam_role {
    role_arn = local.create_external_catalog_iam_role ? aws_iam_role.dbx_ext_catalog_role[0].arn : local.effective_external_catalog_iam_role_arn
  }

  isolation_mode = "ISOLATION_MODE_ISOLATED"
}

resource "databricks_grants" "dbx_admins_service_creds_grants" {
  count    = (var.enable_default_cluster || local.create_external_locations) ? 1 : 0
  provider = databricks.workspace

  credential = databricks_credential.dbx_service_credential[0].id

  grant {
    principal  = data.databricks_group.this["devops_admins"].display_name
    privileges = ["ALL_PRIVILEGES"]
  }

  grant {
    principal  = data.databricks_group.this["domain_admins"].display_name
    privileges = ["ACCESS"]
  }

  grant {
    principal  = data.databricks_group.this["domain_developers"].display_name
    privileges = ["ACCESS"]
  }
}

resource "databricks_external_location" "raw_dbx_external_location" {
  count    = local.create_external_locations && trimspace(var.raw_external_catalog_s3_url) != "" ? 1 : 0
  provider = databricks.workspace

  depends_on = [
    aws_iam_role_policy.dbx_external_catalog_access,
    aws_s3_object.dbx_team_onboarding_folder_creation
  ]

  name            = "${local.selected_env}-${local.normalized_domain_name}${var.team_name != "" ? "-${var.team_name}" : ""}-dbx-raw-external-location"
  url             = "s3://${var.raw_external_catalog_s3_url}"
  credential_name = databricks_storage_credential.dbx_storage_credential[0].name
  comment         = "RAW external location for ${local.selected_env}_${local.normalized_domain_name}${var.team_name != "" ? "_${var.team_name}" : ""} data"
  isolation_mode  = "ISOLATION_MODE_ISOLATED"
}

resource "databricks_grants" "raw_ext_location_grants" {
  count    = local.create_external_locations && trimspace(var.raw_external_catalog_s3_url) != "" ? 1 : 0
  provider = databricks.workspace

  external_location = databricks_external_location.raw_dbx_external_location[0].name

  grant {
    principal  = data.databricks_group.this["devops_admins"].display_name
    privileges = ["ALL_PRIVILEGES", "MANAGE", "CREATE_EXTERNAL_TABLE"]
  }

  grant {
    principal  = data.databricks_group.this["domain_admins"].display_name
    privileges = ["READ_FILES", "WRITE_FILES", "BROWSE", "CREATE_EXTERNAL_TABLE"]
  }

  grant {
    principal  = data.databricks_group.this["domain_developers"].display_name
    privileges = ["READ_FILES", "WRITE_FILES", "BROWSE"]
  }
}

resource "databricks_external_location" "additional_raw_dbx_external_location" {
  provider = databricks.workspace
  for_each = local.create_external_locations && trimspace(local.effective_additional_external_location_raw_bucket) != "" ? local.prefixes_safe : {}

  depends_on = [
    aws_iam_role_policy.dbx_external_catalog_access,
    aws_s3_object.dbx_team_onboarding_folder_creation
  ]

  name = "${local.selected_env}-${local.normalized_domain_name}${local.team_suffix}-dbx-raw-${each.key}-external-location"

  url             = "s3://${local.effective_additional_external_location_raw_bucket}/${each.value}"
  credential_name = databricks_storage_credential.dbx_storage_credential[0].name
  comment         = "RAW external location for ${local.selected_env}_${local.normalized_domain_name}${var.team_name != "" ? "_${var.team_name}" : ""} at prefix '${each.value}'"
  isolation_mode  = "ISOLATION_MODE_ISOLATED"
}

resource "databricks_grants" "additional_raw_ext_location_grants" {
  provider = databricks.workspace
  for_each = databricks_external_location.additional_raw_dbx_external_location

  external_location = each.value.name

  grant {
    principal  = data.databricks_group.this["devops_admins"].display_name
    privileges = ["ALL_PRIVILEGES", "MANAGE", "CREATE_EXTERNAL_TABLE"]
  }

  grant {
    principal  = data.databricks_group.this["domain_admins"].display_name
    privileges = ["READ_FILES", "WRITE_FILES", "BROWSE", "CREATE_EXTERNAL_TABLE"]
  }

  grant {
    principal  = data.databricks_group.this["domain_developers"].display_name
    privileges = ["READ_FILES", "WRITE_FILES", "BROWSE"]
  }
}

resource "databricks_external_location" "staging_dbx_external_location" {
  count    = local.create_external_locations && trimspace(var.staging_external_catalog_s3_url) != "" ? 1 : 0
  provider = databricks.workspace

  depends_on = [
    aws_iam_role_policy.dbx_external_catalog_access,
    aws_s3_object.dbx_team_onboarding_folder_creation
  ]

  name            = "${local.selected_env}-${local.normalized_domain_name}${var.team_name != "" ? "-${var.team_name}" : ""}-dbx-staging-external-location"
  url             = "s3://${var.staging_external_catalog_s3_url}"
  credential_name = databricks_storage_credential.dbx_storage_credential[0].name
  comment         = "STAGING external location for ${local.selected_env}_${local.normalized_domain_name}${var.team_name != "" ? "_${var.team_name}" : ""} data"
  isolation_mode  = "ISOLATION_MODE_ISOLATED"
}

resource "databricks_grants" "staging_ext_location_grants" {
  count    = local.create_external_locations && trimspace(var.staging_external_catalog_s3_url) != "" ? 1 : 0
  provider = databricks.workspace

  external_location = databricks_external_location.staging_dbx_external_location[0].name

  grant {
    principal  = data.databricks_group.this["devops_admins"].display_name
    privileges = ["ALL_PRIVILEGES", "MANAGE", "CREATE_EXTERNAL_TABLE"]
  }

  grant {
    principal  = data.databricks_group.this["domain_admins"].display_name
    privileges = ["READ_FILES", "WRITE_FILES", "BROWSE", "CREATE_EXTERNAL_TABLE"]
  }

  grant {
    principal  = data.databricks_group.this["domain_developers"].display_name
    privileges = ["READ_FILES", "WRITE_FILES", "BROWSE"]
  }
}

resource "databricks_external_location" "additional_staging_dbx_external_location" {
  provider = databricks.workspace
  for_each = local.create_external_locations && trimspace(local.effective_additional_external_location_staging_bucket) != "" ? local.prefixes_safe : {}

  depends_on = [
    aws_iam_role_policy.dbx_external_catalog_access,
    aws_s3_object.dbx_team_onboarding_folder_creation
  ]

  name = "${local.selected_env}-${local.normalized_domain_name}${local.team_suffix}-dbx-staging-${each.key}-external-location"

  url             = "s3://${local.effective_additional_external_location_staging_bucket}/${each.value}"
  credential_name = databricks_storage_credential.dbx_storage_credential[0].name
  comment         = "STAGING external location for ${local.selected_env}_${local.normalized_domain_name}${var.team_name != "" ? "_${var.team_name}" : ""} at prefix '${each.value}'"
  isolation_mode  = "ISOLATION_MODE_ISOLATED"
}

resource "databricks_grants" "additional_staging_ext_location_grants" {
  provider = databricks.workspace
  for_each = databricks_external_location.additional_staging_dbx_external_location

  external_location = each.value.name

  grant {
    principal  = data.databricks_group.this["devops_admins"].display_name
    privileges = ["ALL_PRIVILEGES", "MANAGE", "CREATE_EXTERNAL_TABLE"]
  }

  grant {
    principal  = data.databricks_group.this["domain_admins"].display_name
    privileges = ["READ_FILES", "WRITE_FILES", "BROWSE", "CREATE_EXTERNAL_TABLE"]
  }

  grant {
    principal  = data.databricks_group.this["domain_developers"].display_name
    privileges = ["READ_FILES", "WRITE_FILES", "BROWSE"]
  }
}

resource "databricks_external_location" "analytics_dbx_external_location" {
  count    = local.create_external_locations && trimspace(var.analytics_external_catalog_s3_url) != "" ? 1 : 0
  provider = databricks.workspace

  depends_on = [
    aws_iam_role_policy.dbx_external_catalog_access,
    aws_s3_object.dbx_team_onboarding_folder_creation
  ]

  name            = "${local.selected_env}-${local.normalized_domain_name}${var.team_name != "" ? "-${var.team_name}" : ""}-dbx-analytics-external-location"
  url             = "s3://${var.analytics_external_catalog_s3_url}"
  credential_name = databricks_storage_credential.dbx_storage_credential[0].name
  comment         = "ANALYTICS external location for ${local.selected_env}_${local.normalized_domain_name}${var.team_name != "" ? "_${var.team_name}" : ""} data"
  isolation_mode  = "ISOLATION_MODE_ISOLATED"
}

resource "databricks_grants" "analytics_ext_location_grants" {
  count    = local.create_external_locations && trimspace(var.analytics_external_catalog_s3_url) != "" ? 1 : 0
  provider = databricks.workspace

  external_location = databricks_external_location.analytics_dbx_external_location[0].name

  grant {
    principal  = data.databricks_group.this["devops_admins"].display_name
    privileges = ["ALL_PRIVILEGES", "MANAGE", "CREATE_EXTERNAL_TABLE"]
  }

  grant {
    principal  = data.databricks_group.this["domain_admins"].display_name
    privileges = ["READ_FILES", "WRITE_FILES", "BROWSE", "CREATE_EXTERNAL_TABLE"]
  }

  grant {
    principal  = data.databricks_group.this["domain_developers"].display_name
    privileges = ["READ_FILES", "WRITE_FILES", "BROWSE"]
  }
}

resource "databricks_external_location" "additional_analytics_dbx_external_location" {
  provider = databricks.workspace
  for_each = local.create_external_locations && trimspace(local.effective_additional_external_location_analytics_bucket) != "" ? local.prefixes_safe : {}

  depends_on = [
    aws_iam_role_policy.dbx_external_catalog_access,
    aws_s3_object.dbx_team_onboarding_folder_creation
  ]

  name = "${local.selected_env}-${local.normalized_domain_name}${local.team_suffix}-dbx-analytics-${each.key}-external-location"

  url             = "s3://${local.effective_additional_external_location_analytics_bucket}/${each.value}"
  credential_name = databricks_storage_credential.dbx_storage_credential[0].name
  comment         = "ANALYTICS external location for ${local.selected_env}_${local.normalized_domain_name}${var.team_name != "" ? "_${var.team_name}" : ""} at prefix '${each.value}'"
  isolation_mode  = "ISOLATION_MODE_ISOLATED"
}

resource "databricks_grants" "additional_analytics_ext_location_grants" {
  provider = databricks.workspace
  for_each = databricks_external_location.additional_analytics_dbx_external_location

  external_location = each.value.name

  grant {
    principal  = data.databricks_group.this["devops_admins"].display_name
    privileges = ["ALL_PRIVILEGES", "MANAGE", "CREATE_EXTERNAL_TABLE"]
  }

  grant {
    principal  = data.databricks_group.this["domain_admins"].display_name
    privileges = ["READ_FILES", "WRITE_FILES", "BROWSE", "CREATE_EXTERNAL_TABLE"]
  }

  grant {
    principal  = data.databricks_group.this["domain_developers"].display_name
    privileges = ["READ_FILES", "WRITE_FILES", "BROWSE"]
  }
}
