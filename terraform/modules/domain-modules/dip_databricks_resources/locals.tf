locals {
  # ------------------------------------------------------------------
  # Domain
  # ------------------------------------------------------------------
  normalized_domain_name    = lower(trimspace(var.domain_name))
  normalized_subdomain_name = lower(trimspace(var.team_name))

  # Convert list-of-strings ("name|description") to a map keyed by name for for_each usage
  additional_catalogs_map = {
    for entry in var.additional_catalogs :
    trimspace(split("|", entry)[0]) => {
      name        = trimspace(split("|", entry)[0])
      description = trimspace(join("|", slice(split("|", entry), 1, length(split("|", entry)))))
    }
  }

  # ------------------------------------------------------------------
  # Git / federation
  # ------------------------------------------------------------------

  # Parse each "repo[@branch]" or "repo[:branch]" entry from var.github_repo.
  # Blank entries are filtered out. Falls back to var.git_branch_name or "main".
  parsed_github_repo_contexts = [
    for repo_ctx in var.github_repo : {
      repo = (
        strcontains(repo_ctx, "@") ? trimspace(split("@", repo_ctx)[0]) :
        strcontains(repo_ctx, ":") ? trimspace(split(":", repo_ctx)[0]) :
        trimspace(repo_ctx)
      )
      branch = (
        strcontains(repo_ctx, "@") ? trimspace(join("@", slice(split("@", repo_ctx), 1, length(split("@", repo_ctx))))) :
        strcontains(repo_ctx, ":") ? trimspace(join(":", slice(split(":", repo_ctx), 1, length(split(":", repo_ctx))))) :
        trimspace(var.git_branch_name) != "" ? trimspace(var.git_branch_name) : "main"
      )
    }
    if trimspace(repo_ctx) != ""
  ]

  repos_to_federate = (
    var.git_integration && length(local.parsed_github_repo_contexts) > 0
    ? local.parsed_github_repo_contexts
    : []
  )

  # ------------------------------------------------------------------
  # Team / external-location path prefixes
  # ------------------------------------------------------------------
  team_suffix = local.normalized_subdomain_name != "" ? "-${local.normalized_subdomain_name}" : ""

  # Default prefix: custom path when provided, otherwise "<domain>/<team>" (or "<domain>")
  default_external_location_prefix = (
    trimspace(var.external_catalog_custom_bucket_path) != "" ? trim(var.external_catalog_custom_bucket_path, "/") : (
      local.normalized_subdomain_name != "" ? "${local.normalized_domain_name}/${local.normalized_subdomain_name}" : local.normalized_domain_name
    )
  )

  # Strip blank entries and leading/trailing slashes from caller-supplied prefixes
  cleaned_additional_external_location_path_prefixes = distinct(compact([
    for p in var.additional_external_location_path_prefixes : (
      trimspace(p) == "" ? null : trim(p, "/")
    )
  ]))

  # Map of safe resource-name key => path prefix (used for external locations)
  effective_prefixes = (
    length(local.cleaned_additional_external_location_path_prefixes) > 0
    ? local.cleaned_additional_external_location_path_prefixes
    : [local.default_external_location_prefix]
  )

  prefixes_safe = {
    for p in local.effective_prefixes :
    trim(replace(trim(p, "/"), "/", "-"), "-") => p
  }

  # Map of safe resource-name key => path prefix (used for Unity Catalog external locations)
  uc_prefixes_safe = {
    for p in var.additional_uc_external_location_path_prefixes :
    trim(replace(trim(p, "/"), "/", "-"), "-") => p
  }
}

locals {
  # Map of service principal application_id => external location privileges
  # Only includes SPs that have been created (integration enabled)
  sp_external_location_grants = merge(
    var.git_integration ? {
      tostring(databricks_service_principal.svc_git[0].application_id) = ["READ_FILES", "WRITE_FILES", "BROWSE"]
    } : {},
    var.atlan_integration ? {
      tostring(databricks_service_principal.svc_atlan[0].application_id) = ["READ_FILES", "WRITE_FILES", "BROWSE"]
    } : {},
    var.dbt_integration ? {
      tostring(databricks_service_principal.svc_dbt[0].application_id) = ["READ_FILES", "WRITE_FILES", "BROWSE"]
    } : {},
    var.spotfire_integration ? {
      tostring(databricks_service_principal.svc_spotfire[0].application_id) = ["READ_FILES", "WRITE_FILES", "BROWSE"]
    } : {},
    var.tableau_integration ? {
      tostring(databricks_service_principal.svc_tableau[0].application_id) = ["READ_FILES", "WRITE_FILES", "BROWSE"]
    } : {},
    var.posit_integration ? {
      tostring(databricks_service_principal.svc_posit[0].application_id) = ["READ_FILES", "WRITE_FILES", "BROWSE"]
    } : {},
    var.sas_integration ? {
      tostring(databricks_service_principal.svc_sas[0].application_id) = ["READ_FILES", "WRITE_FILES", "BROWSE"]
    } : {},
    var.powerapps_integration ? {
      tostring(databricks_service_principal.svc_powerapps[0].application_id) = ["READ_FILES", "WRITE_FILES", "BROWSE"]
    } : {},
  )

  sp_service_credential_grants = merge(
    var.git_integration ? {
      tostring(databricks_service_principal.svc_git[0].application_id) = ["ACCESS"]
    } : {},
    var.atlan_integration ? {
      tostring(databricks_service_principal.svc_atlan[0].application_id) = ["ACCESS"]
    } : {},
    var.dbt_integration ? {
      tostring(databricks_service_principal.svc_dbt[0].application_id) = ["ACCESS"]
    } : {},
    var.spotfire_integration ? {
      tostring(databricks_service_principal.svc_spotfire[0].application_id) = ["ACCESS"]
    } : {},
    var.tableau_integration ? {
      tostring(databricks_service_principal.svc_tableau[0].application_id) = ["ACCESS"]
    } : {},
    var.posit_integration ? {
      tostring(databricks_service_principal.svc_posit[0].application_id) = ["ACCESS"]
    } : {},
    var.sas_integration ? {
      tostring(databricks_service_principal.svc_sas[0].application_id) = ["ACCESS"]
    } : {},
    var.powerapps_integration ? {
      tostring(databricks_service_principal.svc_powerapps[0].application_id) = ["ACCESS"]
    } : {},
  )
}
