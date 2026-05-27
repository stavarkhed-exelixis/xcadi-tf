# dip_databricks Module

## Environment Selection

Terraform variables do not provide a native dropdown in CLI mode.
This module requires `env` as a `list(string)` with exactly one value, and validates it to allow only: `dev`, `test`, `uat`, `prod`.

There is no default environment, so the same module can be reused safely across all environments.

Direct Terraform CLI example:

```powershell
terraform plan -var='env=["dev"]'
```

If your UI writes selected environment to a tfvars file, use:

```hcl
env = ["dev"]
```
