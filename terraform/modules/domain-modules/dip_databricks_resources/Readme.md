# dip_databricks_resources Module

## Environment-Driven Deployment Routing

This module deploys by selected `env` only (`dev`, `test`, `uat`, `prod`, `sbx`).
There is no account-name input variable.

Default routing from env to target account is:

- `dev` -> `clearlake-dev` (`441447966705`)
- `test` -> `clearlake-test` (`154916814622`)
- `uat` -> `clearlake-test` (`154916814622`)
- `prod` -> `clearlake-prod` (`754095075756`)
- `sbx` -> `clearlake-sbx` (`596878271343`)

Terraform can run from DEV, TEST, PROD, or SBX UI/account context. It assumes the env-target backend IRSA role unless Terraform is already running as that exact role, in which case it reuses the current session:

- `dev` -> assumes `dev-xcadi-backend-irsa-role`
- `test`/`uat` -> assumes `test-xcadi-backend-irsa-role`
- `prod` -> assumes `prod-xcadi-backend-irsa-role`
- `sbx` -> assumes `sbx-xcadi-backend-irsa-role`

For `uat`, only the Databricks credentials secret is reused from `test`. Resource names, tags, bucket selection, and all other env-driven conventions still use `uat`.

Default Databricks credential secret routing is:

- `dev` -> `databricks/dip-dev/credentials`
- `test` -> `databricks/dip-test/credentials`
- `uat` -> `databricks/dip-test/credentials`
- `prod` -> `databricks/dip-prod/credentials`
- `sbx` -> `databricks/dip-sbx/credentials`

This behavior is controlled with:

- `aws_account_number_by_env`
- `aws_account_label_by_env`
- `backend_irsa_role_name_by_env`

The default cluster path remains configured to use workspace security group resources in the Databricks account (`create_workspace_security_group_in_databricks_account = true`), which is required when `enable_default_cluster = true`.

Example:

```hcl
env = ["dev"]
```
