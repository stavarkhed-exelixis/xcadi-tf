# dip_databricks_v4 Module

## Environment And Account Selection

Terraform variables do not provide a native dropdown in CLI mode.
This module requires `env` as a `list(string)` with exactly one value, and validates it to allow only: `dev`, `test`, `uat`, `prod`.

`account_number` is optional and controls which AWS account receives the workspace resources and which default raw/staging/analytics bucket set is used.

Default account routing in `v4`:

- `754095075756` supports `dev`, `test`, `uat`, `prod`
- `154916814622` supports `test`, `uat`

Examples:

```powershell
terraform plan -var='env=["uat"]' -var='account_number="754095075756"'
terraform plan -var='env=["uat"]' -var='account_number="154916814622"'
```

With those inputs, `v4` will resolve the default raw/staging/analytics buckets from the matching `account_number + env` map. The root Unity Catalog bucket stays on the Databricks account and changes only by `env`, using `cross_account_role_account_id` by default.

There is no default environment, so the same module can be reused safely across all environments.

Direct Terraform CLI example:

```powershell
terraform plan -var='env=["dev"]'
```

If your UI writes selected environment to a tfvars file, use:

```hcl
env = ["dev"]
account_number = "754095075756"
```
