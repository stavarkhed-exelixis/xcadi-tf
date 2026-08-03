variable "region" {
  description = "The default region for resources within this terraform root."
  type        = string
  default     = "us-west-2"
}

variable "env" {
  description = "Deployment environment as a single-item list (UI-friendly). Allowed values: dev, test, uat, prod. Terraform can run from a single prod execution context and routes to the target account below based on this selection."
  type        = list(string)

  validation {
    condition     = length(var.env) == 1
    error_message = "env must contain exactly one value."
  }

  validation {
    condition = alltrue([
      for e in var.env : contains(["dev", "test", "uat", "prod"], e)
    ])
    error_message = "Invalid environment. Allowed values are dev, test, uat, prod."
  }
}

variable "aws_account_number_by_env" {
  description = "Target AWS account number keyed by environment. Used to route deployments from a prod UI execution context."
  type        = map(string)
  default = {
    dev  = "441447966705"
    test = "154916814622"
    uat  = "154916814622"
    prod = "754095075756"
  }

  validation {
    condition = alltrue([
      for account_num in values(var.aws_account_number_by_env) : can(regex("^[0-9]{12}$", account_num))
    ])
    error_message = "aws_account_number_by_env values must be valid 12-digit AWS account numbers."
  }
}

variable "aws_account_label_by_env" {
  description = "Friendly AWS account label keyed by environment for outputs and diagnostics."
  type        = map(string)
  default = {
    dev  = "clearlake-dev"
    test = "clearlake-test"
    uat  = "clearlake-test"
    prod = "clearlake-prod"
  }
}

variable "backend_irsa_role_name_by_env" {
  description = "Target backend IRSA role name keyed by environment for cross-account assume-role from the prod execution account."
  type        = map(string)
  default = {
    dev  = "dev-xcadi-backend-irsa-role"
    test = "test-xcadi-backend-irsa-role"
    uat  = "test-xcadi-backend-irsa-role"
    prod = "prod-xcadi-backend-irsa-role"
  }

  validation {
    condition = alltrue([
      for role_name in values(var.backend_irsa_role_name_by_env) : trimspace(role_name) != ""
    ])
    error_message = "backend_irsa_role_name_by_env values must be non-empty role names."
  }
}

variable "cluster_name" {
  description = "EKS cluster name suffix. The final cluster name is '$${env}-$${cluster_name}' (e.g. 'dev-dip-xcadi-eks')."
  type        = string
  default     = "dip-xcadi-eks"
}

variable "application" {
  description = "Name of the application"
  type        = string
  default     = "aia"
}

variable "platform" {
  description = "Name of the application"
  type        = string
  default     = "cdp"
}

variable "company" {
  type    = string
  default = "exelixis"
}

variable "cluster_version" {
  type        = string
  description = "Kubernetes `<major>.<minor>` version to use for the EKS cluster"
  default     = "1.31"
}

variable "cluster_enabled_log_types" {
  type        = list(string)
  description = "A list of the desired control plane logs to enable"
  default     = ["audit", "api", "authenticator", "scheduler", "controllerManager"]
}

variable "worker_instance_types" {
  type        = list(string)
  description = "Instance type for worker nodes"
  default     = ["m6i.4xlarge"]
}

variable "worker_max_size" {
  type        = string
  description = "Maximum instances can workers can span"
  default     = "5"
}

variable "worker_min_size" {
  type        = string
  description = "The smallest number of instances that can run by default"
  default     = "2"
}

variable "worker_desired_size" {
  type        = string
  description = "Desired instances that should be running"
  default     = "2"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Subnet IDs for the EKS cluster/nodes in the target env account. Override from the prod UI per env (dev/test/uat/prod) since networking differs by account."
  default     = ["subnet-0375ec97d3b936cf0", "subnet-0707d1e89083057bb", "subnet-0ed72b487b0e8c246"]
}

variable "vpc_id" {
  type        = string
  description = "VPC ID for the EKS cluster in the target env account. Override from the prod UI per env (dev/test/uat/prod) since networking differs by account."
  default     = "vpc-0fe443bd1e0674f19"
}

variable "devops_role_arn" {
  description = "Optional override for the IAM principal ARN (role or user) granted cluster admin access entries (AmazonEKSAdminViewPolicy, AmazonEKSClusterAdminPolicy, AmazonEKSAdminPolicy). If null, the module derives the ARN from devops_role_arn_by_env keyed by the selected env."
  type        = string
  default     = null
  nullable    = true
}

variable "devops_role_arn_by_env" {
  description = "Default devops SSO role ARN granted EKS cluster admin access entries, keyed by environment. uat reuses the test account role. Used when devops_role_arn is not explicitly set."
  type        = map(string)
  default = {
    dev  = "arn:aws:iam::441447966705:role/aws-reserved/sso.amazonaws.com/us-west-2/AWSReservedSSO_exelixis-devops-opal_8567b8295f25a584"
    test = "arn:aws:iam::154916814622:role/aws-reserved/sso.amazonaws.com/us-west-2/AWSReservedSSO_exelixis-devops-opal_ce532bb2097734c5"
    uat  = "arn:aws:iam::154916814622:role/aws-reserved/sso.amazonaws.com/us-west-2/AWSReservedSSO_exelixis-devops-opal_ce532bb2097734c5"
    prod = "arn:aws:iam::754095075756:role/aws-reserved/sso.amazonaws.com/us-west-2/AWSReservedSSO_exelixis-devops-opal_29f64b57a08f0aed"
  }

  validation {
    condition = alltrue([
      for k in ["dev", "test", "uat", "prod"] : contains(keys(var.devops_role_arn_by_env), k)
    ])
    error_message = "devops_role_arn_by_env must include keys for dev, test, uat, and prod."
  }

  validation {
    condition = alltrue([
      for arn in values(var.devops_role_arn_by_env) : can(regex("^arn:aws:iam::[0-9]{12}:", arn))
    ])
    error_message = "devops_role_arn_by_env values must be valid IAM ARNs (arn:aws:iam::<account>:...)."
  }
}

variable "kms_key_administrators" {
  description = "Optional override list of IAM principal ARNs to grant administrative access to the EKS cluster's KMS key, in addition to the cluster creator. If empty, the module derives the list from kms_key_administrators_by_env keyed by the selected env."
  type        = list(string)
  default     = []
}

variable "kms_key_administrators_by_env" {
  description = "Default set of IAM principal ARNs granted administrative access to the EKS cluster's KMS key, keyed by environment. uat reuses the test account roles. Used when kms_key_administrators is not explicitly set."
  type        = map(list(string))
  default = {
    dev = [
      "arn:aws:iam::441447966705:role/aws-reserved/sso.amazonaws.com/us-west-2/AWSReservedSSO_AWSAdministratorAccess-opal_41d20c457741fea1",
      "arn:aws:iam::441447966705:role/aws-reserved/sso.amazonaws.com/us-west-2/AWSReservedSSO_clearlake-daplex-devops-opal_edc84091ba6f4be9",
      "arn:aws:iam::441447966705:role/aws-reserved/sso.amazonaws.com/us-west-2/AWSReservedSSO_exelixis-devops-opal_8567b8295f25a584"
    ]
    test = [
      "arn:aws:iam::154916814622:role/aws-reserved/sso.amazonaws.com/us-west-2/AWSReservedSSO_AWSAdministratorAccess-opal_7b6d4c44ca677377",
      "arn:aws:iam::154916814622:role/aws-reserved/sso.amazonaws.com/us-west-2/AWSReservedSSO_clearlake-daplex-devops-opal_e9fb22e087aaef88",
      "arn:aws:iam::154916814622:role/aws-reserved/sso.amazonaws.com/us-west-2/AWSReservedSSO_exelixis-devops-opal_ce532bb2097734c5"
    ]
    uat = [
      "arn:aws:iam::154916814622:role/aws-reserved/sso.amazonaws.com/us-west-2/AWSReservedSSO_AWSAdministratorAccess-opal_7b6d4c44ca677377",
      "arn:aws:iam::154916814622:role/aws-reserved/sso.amazonaws.com/us-west-2/AWSReservedSSO_clearlake-daplex-devops-opal_e9fb22e087aaef88",
      "arn:aws:iam::154916814622:role/aws-reserved/sso.amazonaws.com/us-west-2/AWSReservedSSO_exelixis-devops-opal_ce532bb2097734c5"
    ]
    prod = [
      "arn:aws:iam::754095075756:role/aws-reserved/sso.amazonaws.com/us-west-2/AWSReservedSSO_AWSAdministratorAccess-opal_b59502e583c87608",
      "arn:aws:iam::754095075756:role/aws-reserved/sso.amazonaws.com/us-west-2/AWSReservedSSO_clearlake-daplex-devops-opal_09f1901d9795673c",
      "arn:aws:iam::754095075756:role/aws-reserved/sso.amazonaws.com/us-west-2/AWSReservedSSO_exelixis-devops-opal_29f64b57a08f0aed"
    ]
  }

  validation {
    condition = alltrue([
      for k in ["dev", "test", "uat", "prod"] : contains(keys(var.kms_key_administrators_by_env), k)
    ])
    error_message = "kms_key_administrators_by_env must include keys for dev, test, uat, and prod."
  }

  validation {
    condition = alltrue(flatten([
      for arn_list in values(var.kms_key_administrators_by_env) : [
        for arn in arn_list : can(regex("^arn:aws:iam::[0-9]{12}:", arn))
      ]
    ]))
    error_message = "kms_key_administrators_by_env values must be lists of valid IAM ARNs (arn:aws:iam::<account>:...)."
  }
}

variable "ebs_device_name" {
  type        = string
  description = " The device name to expose to the instance"
  default     = "/dev/xvda"
}

variable "ebs_volume_size" {
  type        = string
  description = "The size of the drive in GiBs"
  default     = "120"
}

variable "ebs_volume_type" {
  type        = string
  description = "The type of EBS volume"
  default     = "gp3"
}

variable "ebs_volume_iops" {
  type        = string
  description = "The amount of IOPS to provision for the disk."
  default     = "3000"
}

variable "ebs_volume_throughput" {
  type        = string
  description = "The throughput (MiB/s) to provision for the gp3 disk."
  default     = "125"
}
