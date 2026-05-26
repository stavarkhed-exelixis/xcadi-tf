locals {
  parsed_github_repo_contexts = [
    for repo_ctx in var.github_repo : {
      repo = strcontains(repo_ctx, "@") ? trimspace(split("@", repo_ctx)[0]) : (
        strcontains(repo_ctx, ":") ? trimspace(split(":", repo_ctx)[0]) : trimspace(repo_ctx)
      )
      branch = strcontains(repo_ctx, "@") ? trimspace(join("@", slice(split("@", repo_ctx), 1, length(split("@", repo_ctx))))) : (
        strcontains(repo_ctx, ":") ? trimspace(join(":", slice(split(":", repo_ctx), 1, length(split(":", repo_ctx))))) : (
          trimspace(var.git_branch_name) != "" ? trimspace(var.git_branch_name) : "main"
        )
      )
    }
    if trimspace(repo_ctx) != ""
  ]

  repos_to_federate = var.git_integration ? (
    length(local.parsed_github_repo_contexts) > 0 ? local.parsed_github_repo_contexts : []
  ) : []

  team_suffix = var.team_name != "" ? "-${var.team_name}" : ""

  default_external_location_prefix = var.team_name != "" ? "${var.domain_name}/${var.team_name}" : var.domain_name

  prefixes_safe = {
    for p in(length(var.additional_external_location_path_prefixes) > 0 ? var.additional_external_location_path_prefixes : [local.default_external_location_prefix]) :
    trim(replace(trim(p, "/"), "/", "-"), "-") => p
  }

  uc_prefixes_safe = {
    for p in var.additional_uc_external_location_path_prefixes :
    trim(replace(trim(p, "/"), "/", "-"), "-") => p
  }
}
