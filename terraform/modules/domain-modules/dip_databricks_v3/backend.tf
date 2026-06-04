terraform {
  backend "s3" {
    bucket       = "exelixis-cl-dip-dev-us-west-2-441447966705-xcadi-tf-state"
    key          = "xcadi/441447966705/dev/us-west-2/domain-modules/databricks.tfstate"
    region       = "us-west-2"
    use_lockfile = true
    encrypt      = true
  }
}
