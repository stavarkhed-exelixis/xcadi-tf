locals {
  create_external_catalog_iam_role = var.enable_external_catalog_iam_role && trimspace(var.unity_catalog_role_arn) != ""
  ext_catalog_role_name            = "${local.selected_env}-${local.normalized_domain_name}${var.team_name != "" ? "-${var.team_name}" : ""}-${var.external_catalog_iam_role_name_suffix}"

  ext_catalog_single_prefix = trimspace(var.external_catalog_custom_bucket_path) != "" ? trim(var.external_catalog_custom_bucket_path, "/") : "${local.normalized_domain_name}${var.team_name != "" ? "/${var.team_name}" : ""}"

  ext_catalog_effective_prefixes = distinct(
    concat(
      length(var.external_catalog_s3_path_prefixes) > 0 ? var.external_catalog_s3_path_prefixes : [local.ext_catalog_single_prefix],
      local.cleaned_additional_external_location_path_prefixes
    )
  )

  ext_catalog_buckets = distinct(compact([
    local.effective_additional_external_location_raw_bucket,
    local.effective_additional_external_location_staging_bucket,
    local.effective_additional_external_location_analytics_bucket
  ]))

  ext_catalog_bucket_map = {
    raw       = local.effective_additional_external_location_raw_bucket
    staging   = local.effective_additional_external_location_staging_bucket
    analytics = local.effective_additional_external_location_analytics_bucket
  }

  ext_catalog_dynamic_s3_paths = flatten([
    for prefix in local.ext_catalog_effective_prefixes : flatten([
      [for bucket in local.ext_catalog_buckets : "arn:aws:s3:::${bucket}/${prefix}/*"],
      [for bucket in local.ext_catalog_buckets : "arn:aws:s3:::${bucket}/${prefix}"]
    ])
  ])

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
}

resource "aws_iam_role" "dbx_ext_catalog_role" {
  count = local.create_external_catalog_iam_role ? 1 : 0

  name = local.ext_catalog_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
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
    ]
  })

  tags = local.effective_tags
}

resource "aws_iam_role_policy" "dbx_external_catalog_access" {
  count = local.create_external_catalog_iam_role ? 1 : 0

  name = "${local.selected_env}-${local.normalized_domain_name}${var.team_name != "" ? "-${var.team_name}" : ""}-dbx-ext-catalog-rw-policy"
  role = aws_iam_role.dbx_ext_catalog_role[0].id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:CopyObject",
          "s3:PutObject*",
          "s3:Get*",
          "s3:DeleteObject*",
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:GetLifecycleConfiguration",
          "s3:PutLifecycleConfiguration"
        ],
        Resource = local.ext_catalog_dynamic_s3_paths
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
          "s3:ListBucket"
        ],
        Resource = [
          "arn:aws:s3:::${local.effective_additional_external_location_raw_bucket}",
          "arn:aws:s3:::${local.effective_additional_external_location_staging_bucket}",
          "arn:aws:s3:::${local.effective_additional_external_location_analytics_bucket}"
        ]
      },
      {
        Sid    = "SecretsManagerReadPermissions",
        Effect = "Allow",
        Action = [
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue"
        ],
        Resource = ["arn:aws:secretsmanager:${var.aws_region}:${local.env_account_id}:secret:${local.selected_env}-${local.normalized_domain_name}${var.team_name != "" ? "-${var.team_name}" : ""}-*"]
      },
      {
        Sid      = "AWSSecretsManagerListPermissions",
        Effect   = "Allow",
        Action   = ["secretsmanager:ListSecrets"],
        Resource = ["*"]
      }
    ]
  })
}

resource "aws_s3_object" "dbx_team_onboarding_folder_creation" {
  for_each = local.create_external_catalog_iam_role && var.enable_external_catalog_s3_prefix_creation ? local.ext_catalog_bootstrap_objects : {}

  bucket  = each.value.bucket
  key     = each.value.key
  content = ""
}
