locals {
  create_external_catalog_iam_role = var.enable_external_catalog_iam_role && trimspace(var.unity_catalog_role_arn) != ""
  ext_catalog_role_name            = "${local.selected_env}-${local.normalized_domain_name}${local.normalized_subdomain_name != "" ? "-${local.normalized_subdomain_name}" : ""}-${var.external_catalog_iam_role_name_suffix}"

  ext_catalog_single_prefix = trimspace(var.external_catalog_custom_bucket_path) != "" ? trim(var.external_catalog_custom_bucket_path, "/") : "${local.normalized_domain_name}${local.normalized_subdomain_name != "" ? "/${local.normalized_subdomain_name}" : ""}"

  ext_catalog_effective_prefixes = distinct(
    concat(
      length(var.external_catalog_s3_path_prefixes) > 0 ? var.external_catalog_s3_path_prefixes : [local.ext_catalog_single_prefix],
      local.cleaned_additional_external_location_path_prefixes
    )
  )

  ext_catalog_buckets = distinct(compact(concat([
    local.effective_additional_external_location_raw_bucket,
    local.effective_additional_external_location_staging_bucket,
    local.effective_additional_external_location_analytics_bucket,
    ],
    local.additional_external_location_buckets,
  )))

  ext_catalog_bucket_map = {
    raw       = local.effective_additional_external_location_raw_bucket
    staging   = local.effective_additional_external_location_staging_bucket
    analytics = local.effective_additional_external_location_analytics_bucket
  }

  ext_catalog_bucket_arns = [
    for bucket in local.ext_catalog_buckets : "arn:aws:s3:::${bucket}"
  ]

  ext_catalog_object_s3_paths = distinct(concat(
    flatten([
      for prefix in local.ext_catalog_effective_prefixes : flatten([
        [for bucket in local.ext_catalog_buckets : "arn:aws:s3:::${bucket}/${prefix}/*"],
        [for bucket in local.ext_catalog_buckets : "arn:aws:s3:::${bucket}/${prefix}"]
      ])
    ]),
    # Also permit each additional external location's own bucket + prefix
    # combination explicitly. Handles arbitrary bucket/path pairs supplied
    # via var.additional_external_locations.
    local.additional_external_location_object_arns,
  ))

  ext_catalog_bootstrap_objects = {
    for item in flatten([
      for bucket in local.ext_catalog_buckets : [
        for prefix in local.ext_catalog_effective_prefixes : {
          id     = "${bucket}:${trim(replace(trim(prefix, "/"), "/", "-"), "-")}"
          bucket = bucket
          key    = "${trim(prefix, "/")}/"
        }
      ]
      ]) : item.id => {
      bucket = item.bucket
      key    = item.key
    }
  }

  # Bootstrap folder placeholders for each additional external location
  # entry. Every entry in var.additional_external_locations has a non-empty
  # prefix (enforced by variable validation), so a folder marker is created
  # for each.
  ext_catalog_additional_bootstrap_objects = local.additional_external_location_bootstrap_objects

  ext_catalog_additional_trusted_role_arns   = distinct(compact([for arn in var.additional_trusted_role_arns : trimspace(arn)]))
  ext_catalog_additional_assumable_role_arns = distinct(compact([for arn in var.additional_assumable_role_arns : trimspace(arn)]))
}

resource "aws_iam_role" "dbx_ext_catalog_role" {
  count = local.create_external_catalog_iam_role ? 1 : 0

  name = local.ext_catalog_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Effect = "Allow"
          Principal = {
            AWS = var.unity_catalog_role_arn
          }
          Action = "sts:AssumeRole"
          Condition = {
            StringEquals = {
              "sts:ExternalId" = local.databricks_account_id
            }
          }
        },
        {
          Effect = "Allow"
          Principal = {
            AWS = "arn:aws:iam::${local.env_account_id}:root"
          }
          Action = "sts:AssumeRole"
          Condition = {
            StringEquals = {
              "sts:ExternalId"   = local.databricks_account_id
              "AWS:PrincipalArn" = "arn:aws:iam::${local.env_account_id}:role/${local.ext_catalog_role_name}"
            }
          }
        }
      ],
      [
        for trusted_role_arn in local.ext_catalog_additional_trusted_role_arns : {
          Effect = "Allow"
          Principal = {
            AWS = trusted_role_arn
          }
          Action = "sts:AssumeRole"
        }
      ]
    )
  })

  tags = local.effective_tags
}

resource "aws_iam_role_policy" "dbx_external_catalog_access" {
  count = local.create_external_catalog_iam_role ? 1 : 0

  name = "${local.selected_env}-${local.normalized_domain_name}${local.normalized_subdomain_name != "" ? "-${local.normalized_subdomain_name}" : ""}-dbx-ext-catalog-rw-policy"
  role = aws_iam_role.dbx_ext_catalog_role[0].id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = concat(
      [
        {
          Effect = "Allow",
          Action = [
            "s3:GetObject",
            "s3:PutObject",
            "s3:DeleteObject",
            "s3:CopyObject",
            "s3:PutObject*",
            "s3:Get*",
            "s3:DeleteObject*"
          ],
          Resource = local.ext_catalog_object_s3_paths
        },
        {
          Effect = "Allow",
          Action = [
            "sts:AssumeRole"
          ],
          Resource = "arn:aws:iam::${local.env_account_id}:role/${local.ext_catalog_role_name}"
        },
        {
          Effect   = "Allow",
          Action   = ["s3:ListAllMyBuckets"],
          Resource = ["*"]
        },
        {
          Effect = "Allow",
          Action = [
            "s3:ListBucket",
            "s3:GetBucketLocation",
            "s3:GetLifecycleConfiguration",
            "s3:PutLifecycleConfiguration"
          ],
          Resource = local.ext_catalog_bucket_arns
        },
        {
          Sid    = "SecretsManagerReadPermissions",
          Effect = "Allow",
          Action = [
            "secretsmanager:DescribeSecret",
            "secretsmanager:GetSecretValue",
            "secretsmanager:UpdateSecret"
          ],
          Resource = ["arn:aws:secretsmanager:${var.aws_region}:${local.env_account_id}:secret:${local.selected_env}-${local.normalized_domain_name}${local.normalized_subdomain_name != "" ? "-${local.normalized_subdomain_name}" : ""}-*"]
        },
        {
          Sid      = "AWSSecretsManagerListPermissions",
          Effect   = "Allow",
          Action   = ["secretsmanager:ListSecrets"],
          Resource = ["*"]
        }
      ],
      [
        for role_arn in local.ext_catalog_additional_assumable_role_arns : {
          Effect = "Allow",
          Action = [
            "sts:AssumeRole"
          ],
          Resource = role_arn
        }
      ]
    )
  })
}

resource "aws_s3_object" "dbx_team_onboarding_folder_creation" {
  for_each = var.enable_external_catalog_s3_prefix_creation && local.create_external_locations ? local.ext_catalog_bootstrap_objects : {}

  bucket  = each.value.bucket
  key     = each.value.key
  content = ""
}

resource "aws_s3_object" "dbx_team_onboarding_folder_creation_additional" {
  for_each = var.enable_external_catalog_s3_prefix_creation && local.create_external_locations ? local.ext_catalog_additional_bootstrap_objects : {}

  bucket  = each.value.bucket
  key     = each.value.key
  content = ""
}
