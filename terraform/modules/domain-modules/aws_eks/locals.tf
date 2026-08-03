locals {
  account_id = data.aws_caller_identity.current.id
  common_tags = {
    # Unsure about UCOA for DnA resources within Clearlake (using Commercial Ops UCOA for now)
    UCOA           = "1000011007020086"                     # general ledger identification code <business-entity><location-code><cost-center>
    Product        = "Cloud Data Platform"                  # Product
    ProductOwner   = "Prashanth Mamidala"                   # Product Owner <first> <last>
    ProductManager = "Rajiv Arora"                          # Product Manager <first> <last>
    Environment    = local.selected_env                     # Level of environment <prod, test, uat, dev>
    classification = "confidential"                         # schema classification <classification>
    compliance     = "NA"                                   # Compliance schema <PII, PHI, GDPR, HIPAA, NA>
    Operations     = "terraform"                            # Operations management scheme <terraform, cloudformation, manual
    Identifier     = "3e7908e3-c111-4f94-8a39-1d6842c981fc" # Generate UUID for each project <https://www.uuidgenerator.net/>
    network        = "on-prem"                              # VPC connectivity <island, onprem>
  }
  region = data.aws_region.current.name
}


locals {
  vpc_cidr            = ["10.98.176.0/20"]
  zscaler_cidr_blocks = ["172.29.0.0/16", "172.19.0.0/16"]
  prefix_list_ids     = ["pl-0e3949231454f3679", "pl-04a3dbacad5e58717", "pl-0d97e7f6ef8f25ef9"]

  s3_data_buckets_arn = [
    "arn:aws:s3:::exelixis-clearlake-daplex-${local.selected_env}-${var.region}-${local.selected_account_number}-raw",
    "arn:aws:s3:::exelixis-clearlake-daplex-${local.selected_env}-${var.region}-${local.selected_account_number}-staging",
    "arn:aws:s3:::exelixis-clearlake-daplex-${local.selected_env}-${var.region}-${local.selected_account_number}-analytics",
    "arn:aws:s3:::exelixis-cdp-${local.selected_env}-${var.region}-${local.selected_account_number}-query-results"
  ]

  s3_data_buckets_default_prefix_arn = [
    "arn:aws:s3:::exelixis-clearlake-daplex-${local.selected_env}-${var.region}-${local.selected_account_number}-raw/*",
    "arn:aws:s3:::exelixis-clearlake-daplex-${local.selected_env}-${var.region}-${local.selected_account_number}-staging/*",
    "arn:aws:s3:::exelixis-clearlake-daplex-${local.selected_env}-${var.region}-${local.selected_account_number}-analytics/*",
    "arn:aws:s3:::exelixis-cdp-${local.selected_env}-${var.region}-${local.selected_account_number}-query-results/*"
  ]
}
