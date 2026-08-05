resource "random_string" "suffix_v2" {
  length  = 8
  special = false
}

module "alb_controller_irsa_role_v2" {
  # Pinned to the same commit as registry version 5.52.2. Uses an HTTPS zip archive
  # (instead of the registry's git:: source) so `terraform init` does not require git.
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.52.2"

  role_name                              = "${module.eks_v2.cluster_name}-alb-controller"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    ex = {
      provider_arn               = module.eks_v2.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller-sa"]
    }
  }
}

module "vpc_cni_irsa_role_v2" {
  #source    = "https://github.com/terraform-aws-modules/terraform-aws-iam/archive/e803e25ce20a6ebd5579e0896f657fa739f6f03e.zip//terraform-aws-iam-e803e25ce20a6ebd5579e0896f657fa739f6f03e/modules/iam-role-for-service-accounts-eks"
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "6.7.0"
  role_name = "${module.eks_v2.cluster_name}-vpc-cni"

  attach_vpc_cni_policy = true
  vpc_cni_enable_ipv4   = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks_v2.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-node"]
    }
  }
  tags = local.common_tags
}

# irsa - csi ebs storage
module "ebs_csi_irsa_role_v2" {
  #source                = "https://github.com/terraform-aws-modules/terraform-aws-iam/archive/e803e25ce20a6ebd5579e0896f657fa739f6f03e.zip//terraform-aws-iam-e803e25ce20a6ebd5579e0896f657fa739f6f03e/modules/iam-role-for-service-accounts-eks"
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.52.2"
  role_name             = "${module.eks_v2.cluster_name}-ebs-csi"
  attach_ebs_csi_policy = true

  oidc_providers = {
    ex = {
      provider_arn               = module.eks_v2.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
  tags = local.common_tags
}


module "efs_csi_irsa_role_v2" {
  #source                = "https://github.com/terraform-aws-modules/terraform-aws-iam/archive/e803e25ce20a6ebd5579e0896f657fa739f6f03e.zip//terraform-aws-iam-e803e25ce20a6ebd5579e0896f657fa739f6f03e/modules/iam-role-for-service-accounts-eks"
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.52.2"
  role_name             = "${module.eks_v2.cluster_name}-efs-csi"
  attach_efs_csi_policy = true

  oidc_providers = {
    ex = {
      provider_arn               = module.eks_v2.oidc_provider_arn
      namespace_service_accounts = ["kube-system:efs-csi-controller-sa", "kube-system:efs-csi-node-sa"]
    }
  }
  tags = local.common_tags
}

module "s3_mountpoint_irsa_role_v2" {
  #source                          = "https://github.com/terraform-aws-modules/terraform-aws-iam/archive/e803e25ce20a6ebd5579e0896f657fa739f6f03e.zip//terraform-aws-iam-e803e25ce20a6ebd5579e0896f657fa739f6f03e/modules/iam-role-for-service-accounts-eks"
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.52.2"
  role_name                       = "${module.eks_v2.cluster_name}-s3-mountpoint-csi"
  attach_mountpoint_s3_csi_policy = true
  mountpoint_s3_csi_bucket_arns   = local.s3_data_buckets_arn
  mountpoint_s3_csi_path_arns     = local.s3_data_buckets_default_prefix_arn

  oidc_providers = {
    ex = {
      provider_arn               = module.eks_v2.oidc_provider_arn
      namespace_service_accounts = ["kube-system:s3-mountpoint-csi-controller-sa"]
    }
  }
  tags = local.common_tags
}

module "cloudwatch_observability_role_v2" {
  #source                                 = "https://github.com/terraform-aws-modules/terraform-aws-iam/archive/e803e25ce20a6ebd5579e0896f657fa739f6f03e.zip//terraform-aws-iam-e803e25ce20a6ebd5579e0896f657fa739f6f03e/modules/iam-role-for-service-accounts-eks"
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.52.2"
  role_name                              = "${module.eks_v2.cluster_name}-cloudwatch-observability"
  attach_cloudwatch_observability_policy = true

  oidc_providers = {
    ex = {
      provider_arn               = module.eks_v2.oidc_provider_arn
      namespace_service_accounts = ["amazon-cloudwatch:cloudwatch-agent"]
    }
  }
  tags = local.common_tags
}

module "eks_v2" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "20.37.1"
  cluster_name    = "${local.selected_env}-${var.cluster_name}"
  cluster_version = var.cluster_version

  #networking
  subnet_ids = var.private_subnet_ids
  vpc_id     = var.vpc_id

  //enable logs and OIDC
  cluster_enabled_log_types = var.cluster_enabled_log_types
  enable_irsa               = true

  //cluster_sg_rules
  cluster_security_group_additional_rules = {
    default-rules = {
      prefix_list_ids = local.prefix_list_ids
      description     = "Allow traffic from Onprem and VDI nnetwork"
      from_port       = 443
      to_port         = 443
      protocol        = "tcp"
      type            = "ingress"
      self            = false
    }
    zscaler = {
      cidr_blocks = local.zscaler_cidr_blocks
      description = "Allow traffic from zscaler VPN"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      type        = "ingress"
    }
    vpc = {
      cidr_blocks = local.vpc_cidr
      description = "Allow all traffic on VPC"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
    }
    global-outbound-access = {
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow all traffic outbound"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "egress"
    }
  }

  # install the add-ons
  cluster_addons = {
    kube-proxy = {
      most_recent = true
    }
    metrics-server = {
      most_recent = true
      configuration_values = jsonencode({
        tolerations = [{
          effect : "NoSchedule",
          key : "dedicated",
          operator : "Equal",
          value : "management_nodes"
        }]
      })
    }
    coredns = {
      most_recent = true
      configuration_values = jsonencode({
        tolerations = [{
          effect : "NoSchedule",
          key : "dedicated",
          operator : "Equal",
          value : "management_nodes"
        }]
      })
    }
    vpc-cni = {
      most_recent              = true
      service_account_role_arn = module.vpc_cni_irsa_role_v2.iam_role_arn
    }
    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = module.ebs_csi_irsa_role_v2.iam_role_arn
      configuration_values = jsonencode({
        controller : {
          tolerations : [
            {
              effect : "NoSchedule",
              key : "dedicated",
              operator : "Equal",
              value : "management_nodes"
            }
          ]
        }
      })
    }
    aws-efs-csi-driver = {
      most_recent              = true
      service_account_role_arn = module.efs_csi_irsa_role_v2.iam_role_arn
      configuration_values = jsonencode({
        controller : {
          tolerations : [
            {
              effect : "NoSchedule",
              key : "dedicated",
              operator : "Equal",
              value : "management_nodes"
            }
          ]
        }
      })
    }
    aws-mountpoint-s3-csi-driver = {
      most_recent              = true
      service_account_role_arn = module.s3_mountpoint_irsa_role_v2.iam_role_arn
      configuration_values = jsonencode({
        controller : {
          tolerations : [
            {
              effect : "NoSchedule",
              key : "dedicated",
              operator : "Equal",
              value : "management_nodes"
            }
          ]
        }
      })
    }
    amazon-cloudwatch-observability = {
      most_recent              = true
      service_account_role_arn = module.cloudwatch_observability_role_v2.iam_role_arn
      configuration_values = jsonencode({
        manager : {
          tolerations : [
            {
              effect : "NoSchedule",
              key : "dedicated",
              operator : "Equal",
              value : "management_nodes"
            }
          ]
        }
      })
    }
  }

  //access_entries_on_cluster
  access_entries = {
    devops_role = {
      principal_arn = local.effective_devops_role_arn
      policy_associations = [
        {
          policy_arn  = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminViewPolicy"
          policy_name = "AdminViewer"
          access_scope = {
            type = "cluster"
          }
        },
        {
          policy_arn  = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          policy_name = "ClusterAdmin"
          access_scope = {
            type = "cluster"
          }
        },
        {
          policy_arn  = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminPolicy"
          policy_name = "Admin"
          access_scope = {
            type = "cluster"
          }
        }
      ]
    }
  }

  #we need to specify appropriate key owners for the account, the role hash will be different for account.
  kms_key_administrators = local.effective_kms_key_administrators

  # make worker nodes work with SSM
  eks_managed_node_group_defaults = {
    #instance_types             = [var.worker_instance_types]
    iam_role_attach_cni_policy = true
    block_device_mappings = {
      xvda = {
        device_name = var.ebs_device_name
        ebs = {
          volume_size           = var.ebs_volume_size
          volume_type           = var.ebs_volume_type
          iops                  = var.ebs_volume_iops
          throughput            = var.ebs_volume_throughput
          encrypted             = true
          delete_on_termination = true
        }
      }
    }
    iam_role_additional_policies = {
      "SSM-policy" = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
      "CW-policy"  = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
    }
  }

  node_security_group_additional_rules = {
    ingress_allow_access_from_nodes = {
      description = "Node to node access"
      type        = "ingress"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      self        = true
    }
    egress_allow_access_to_nodes = {
      description = "Node to node access"
      type        = "egress"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      self        = true
    }
    ingress_allow_access_from_control_plane = {
      description                   = "Cluster to node access"
      protocol                      = "-1"
      from_port                     = 0
      to_port                       = 0
      type                          = "ingress"
      source_cluster_security_group = true
    }
    ingress_allow_traffic_for_vpc = {
      cidr_blocks = local.vpc_cidr
      description = "Allow all traffic on VPC"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
    }
  }


  eks_managed_node_groups = {
    management_nodes = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = ["m6i.4xlarge"]
      name           = "management-nodes"
      max_size       = var.worker_max_size
      min_size       = var.worker_min_size
      desired_size   = var.worker_desired_size
      taints = {
        management = {
          key    = "dedicated"
          value  = "management_nodes"
          effect = "NO_SCHEDULE"
        }
      }
    }
  }
  tags = local.common_tags
}
