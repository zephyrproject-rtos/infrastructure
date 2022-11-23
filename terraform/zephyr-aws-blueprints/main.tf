provider "aws" {
  region = var.aws_region
}

provider "kubernetes" {
  host                   = module.eks_blueprints.eks_cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_blueprints.eks_cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "kubectl" {
  host                   = module.eks_blueprints.eks_cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_blueprints.eks_cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
  load_config_file       = false
}

provider "helm" {
  kubernetes {
    host                   = module.eks_blueprints.eks_cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks_blueprints.eks_cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

provider "github" {
  owner = var.github_organization
}

data "aws_eks_cluster_auth" "this" {
  name = module.eks_blueprints.eks_cluster_id
}

data "aws_ami" "amazonlinux2eks" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amazon-eks-node-${local.cluster_version}-*"]
  }

  owners = ["amazon"]
}

data "aws_ami" "zephyr_runner_node_x86_64" {
  most_recent = true

  filter {
    name   = "name"
    values = ["zephyr-runner-node-x86_64-1669044340"]
  }

  owners = ["724087766192"]
}

data "aws_ami" "zephyr_runner_node_arm64" {
  most_recent = true

  filter {
    name   = "name"
    values = ["zephyr-runner-node-arm64-1669044291"]
  }

  owners = ["724087766192"]
}

data "aws_availability_zones" "available" {}

locals {
  cluster_version = "1.23"

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = {
    Blueprint  = var.cluster_name
    GithubRepo = "github.com/zephyrproject-rtos/infrastructure-private"
  }
}

#---------------------------------------------------------------
# EKS Blueprints
#---------------------------------------------------------------
module "eks_blueprints" {
  source = "./terraform-aws-eks-blueprints"

  cluster_name    = var.cluster_name
  cluster_version = local.cluster_version

  # AWS identity mapping
  map_users = var.aws_auth_map_users

  # Network configurations
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnets

  node_security_group_additional_rules = {
    # Extend node-to-node security group rules. Recommended and required for the Add-ons
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    # Recommended outbound traffic for Node groups
    egress_all = {
      description      = "Node all egress"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
    # Allows Control Plane Nodes to talk to Worker nodes on all ports. Added this to simplify the example and further avoid issues with Add-ons communication with Control plane.
    # This can be restricted further to specific port based on the requirement for each Add-on e.g., metrics-server 4443, spark-operator 8080, karpenter 8443 etc.
    # Change this according to your security requirements if needed
    ingress_cluster_to_node_all_traffic = {
      description                   = "Cluster API to Nodegroup all traffic"
      protocol                      = "-1"
      from_port                     = 0
      to_port                       = 0
      type                          = "ingress"
      source_cluster_security_group = true
    }
  }

  # Node group configurations
  managed_node_groups = {
    # On-demand general-purpose x86-64 Linux instances with 8 vCPUs and 16 GiB memory
    od_linux_x64_2xlarge = {
      # Node Group configuration
      node_group_name = "mng-od-linux-x64-2xlarge" # Max 40 characters for node group name

      ami_type               = "AL2_x86_64"    # Available options -> AL2_x86_64, AL2_x86_64_GPU, AL2_ARM_64, CUSTOM
      release_version        = ""              # Enter AMI release version to deploy the latest AMI released by AWS. Used only when you specify ami_type
      capacity_type          = "ON_DEMAND"     # ON_DEMAND or SPOT
      instance_types         = ["c6a.2xlarge"] # List of instances used only for SPOT type
      format_mount_nvme_disk = true            # format and mount NVMe disks ; default to false

      # Launch template configuration
      create_launch_template = true              # false will use the default launch template
      launch_template_os     = "amazonlinux2eks" # amazonlinux2eks or bottlerocket

      enable_monitoring = true
      eni_delete        = true
      public_ip         = false # Use this to enable public IP for EC2 instances; only for public subnets used in launch templates

      http_endpoint               = "enabled"
      http_tokens                 = "optional"
      http_put_response_hop_limit = 3

      # pre_userdata can be used in both cases where you provide custom_ami_id or ami_type
      pre_userdata = <<-EOT
        yum install -y amazon-ssm-agent
        systemctl enable amazon-ssm-agent && systemctl start amazon-ssm-agent
      EOT

      # Taints can be applied through EKS API or through Bootstrap script using kubelet_extra_args
      # e.g., k8s_taints = [{key= "spot", value="true", "effect"="NO_SCHEDULE"}]
      k8s_taints = []

      # Node label configuration
      k8s_labels = {
        instanceType = "on-demand"
        instanceSize = "2xlarge"
        instanceArch = "x64"
        instanceOs   = "linux"
      }

      # Node Group scaling configuration
      desired_size = var.mng_od_linux_x64_2xlarge_desired_size
      max_size     = var.mng_od_linux_x64_2xlarge_max_size
      min_size     = var.mng_od_linux_x64_2xlarge_min_size

      # Block device configuration
      block_device_mappings = [
        {
          device_name = "/dev/xvda"
          volume_type = "gp3"
          volume_size = 200
        }
      ]

      # Node Group network configuration
      subnet_type = "private" # public or private - Default uses the private subnets used in control plane if you don't pass the "subnet_ids"
      subnet_ids  = []        # Defaults to private subnet-ids used by EKS Control plane. Define your private/public subnets list with comma separated subnet_ids  = ['subnet1','subnet2','subnet3']

      additional_iam_policies = [] # Attach additional IAM policies to the IAM role attached to this worker group

      # SSH ACCESS Optional - Recommended to use SSM Session manager
      remote_access         = false
      ec2_ssh_key           = ""
      ssh_security_group_id = ""
    }

    # Spot x86-64 Linux instances with 4 vCPU and 8 GiB memory
    spot_linux_x64_xlarge = {
      node_group_name = "mng-spot-linux-x64-xlarge"

      ami_type        = "CUSTOM"
      custom_ami_id   = data.aws_ami.zephyr_runner_node_x86_64.id
      capacity_type   = "SPOT"
      instance_types  = ["c5a.xlarge", "c6a.xlarge"]

      # Node Group network configuration
      subnet_type = "private" # public or private - Default uses the private subnets used in control plane if you don't pass the "subnet_ids"
      subnet_ids  = []        # Defaults to private subnet-ids used by EKS Control plane. Define your private/public subnets list with comma separated subnet_ids  = ['subnet1','subnet2','subnet3']

      # Node taints
      k8s_taints = [{ key = "spotInstance", value = "true", effect = "NO_SCHEDULE" }]

      # Node label configuration
      k8s_labels = {
        instanceType = "spot"
        instanceSize = "xlarge"
        instanceArch = "x64"
        instanceOs   = "linux"
      }

      # NOTE: If we want the node group to scale-down to zero nodes,
      # we need to use a custom launch template and define some additional tags for the ASGs
      desired_size = var.mng_spot_linux_x64_xlarge_desired_size
      max_size     = var.mng_spot_linux_x64_xlarge_max_size
      min_size     = var.mng_spot_linux_x64_xlarge_min_size

      # Block device configuration
      block_device_mappings = [
        {
          device_name = "/dev/xvda"
          volume_type = "gp3"
          volume_size = 150
        }
      ]

      # Launch template configuration
      create_launch_template = true              # false will use the default launch template
      launch_template_os     = "amazonlinux2eks" # amazonlinux2eks or bottlerocket

      # This is so cluster autoscaler can identify which node (using ASGs tags) to scale-down to zero nodes
      additional_tags = {
        "k8s.io/cluster-autoscaler/node-template/label/eks.amazonaws.com/capacityType" = "SPOT"
        "k8s.io/cluster-autoscaler/node-template/label/eks/node_group_name"            = "mng-spot-linux-x64-xlarge"
        "k8s.io/cluster-autoscaler/node-template/label/instanceType"                   = "spot"
        "k8s.io/cluster-autoscaler/node-template/label/instanceSize"                   = "large"
        "k8s.io/cluster-autoscaler/node-template/label/instanceArch"                   = "x64"
        "k8s.io/cluster-autoscaler/node-template/label/instanceOs"                     = "linux"
      }
    }

    # Spot x86-64 Linux instances with 16 vCPUs and 32 GiB memory
    spot_linux_x64_4xlarge = {
      node_group_name = "mng-spot-linux-x64-4xlarge"

      ami_type        = "CUSTOM"
      custom_ami_id   = data.aws_ami.zephyr_runner_node_x86_64.id
      capacity_type   = "SPOT"
      instance_types  = ["c5a.4xlarge", "c6a.4xlarge"]

      # Node Group network configuration
      subnet_type = "private" # public or private - Default uses the private subnets used in control plane if you don't pass the "subnet_ids"
      subnet_ids  = []        # Defaults to private subnet-ids used by EKS Control plane. Define your private/public subnets list with comma separated subnet_ids  = ['subnet1','subnet2','subnet3']

      # Node taints
      k8s_taints = [{ key = "spotInstance", value = "true", effect = "NO_SCHEDULE" }]

      # Node label configuration
      k8s_labels = {
        instanceType = "spot"
        instanceSize = "4xlarge"
        instanceArch = "x64"
        instanceOs   = "linux"
      }

      # NOTE: If we want the node group to scale-down to zero nodes,
      # we need to use a custom launch template and define some additional tags for the ASGs
      desired_size = var.mng_spot_linux_x64_4xlarge_desired_size
      max_size     = var.mng_spot_linux_x64_4xlarge_max_size
      min_size     = var.mng_spot_linux_x64_4xlarge_min_size

      # Block device configuration
      block_device_mappings = [
        {
          device_name = "/dev/xvda"
          volume_type = "gp3"
          volume_size = 200
        }
      ]

      # Launch template configuration
      create_launch_template = true              # false will use the default launch template
      launch_template_os     = "amazonlinux2eks" # amazonlinux2eks or bottlerocket

      # This is so cluster autoscaler can identify which node (using ASGs tags) to scale-down to zero nodes
      additional_tags = {
        "k8s.io/cluster-autoscaler/node-template/label/eks.amazonaws.com/capacityType" = "SPOT"
        "k8s.io/cluster-autoscaler/node-template/label/eks/node_group_name"            = "mng-spot-linux-x64-4xlarge"
        "k8s.io/cluster-autoscaler/node-template/label/instanceType"                   = "spot"
        "k8s.io/cluster-autoscaler/node-template/label/instanceSize"                   = "4xlarge"
        "k8s.io/cluster-autoscaler/node-template/label/instanceArch"                   = "x64"
        "k8s.io/cluster-autoscaler/node-template/label/instanceOs"                     = "linux"
      }
    }

    # Spot ARM64 Linux instances with 4 vCPU and 8 GiB memory
    spot_linux_arm64_xlarge = {
      node_group_name = "mng-spot-linux-arm64-xlarge"

      ami_type        = "CUSTOM"
      custom_ami_id   = data.aws_ami.zephyr_runner_node_arm64.id
      capacity_type   = "SPOT"
      instance_types  = ["c6g.xlarge", "c6gn.xlarge"]

      # Node Group network configuration
      subnet_type = "private" # public or private - Default uses the private subnets used in control plane if you don't pass the "subnet_ids"
      subnet_ids  = []        # Defaults to private subnet-ids used by EKS Control plane. Define your private/public subnets list with comma separated subnet_ids  = ['subnet1','subnet2','subnet3']

      # Node taints
      k8s_taints = [{ key = "spotInstance", value = "true", effect = "NO_SCHEDULE" }]

      # Node label configuration
      k8s_labels = {
        instanceType = "spot"
        instanceSize = "xlarge"
        instanceArch = "arm64"
        instanceOs   = "linux"
      }

      # NOTE: If we want the node group to scale-down to zero nodes,
      # we need to use a custom launch template and define some additional tags for the ASGs
      desired_size = var.mng_spot_linux_arm64_xlarge_desired_size
      max_size     = var.mng_spot_linux_arm64_xlarge_max_size
      min_size     = var.mng_spot_linux_arm64_xlarge_min_size

      # Block device configuration
      block_device_mappings = [
        {
          device_name = "/dev/xvda"
          volume_type = "gp3"
          volume_size = 150
        }
      ]

      # Launch template configuration
      create_launch_template = true              # false will use the default launch template
      launch_template_os     = "amazonlinux2eks" # amazonlinux2eks or bottlerocket

      # This is so cluster autoscaler can identify which node (using ASGs tags) to scale-down to zero nodes
      additional_tags = {
        "k8s.io/cluster-autoscaler/node-template/label/eks.amazonaws.com/capacityType" = "SPOT"
        "k8s.io/cluster-autoscaler/node-template/label/eks/node_group_name"            = "mng-spot-linux-arm64-xlarge"
        "k8s.io/cluster-autoscaler/node-template/label/instanceType"                   = "spot"
        "k8s.io/cluster-autoscaler/node-template/label/instanceSize"                   = "large"
        "k8s.io/cluster-autoscaler/node-template/label/instanceArch"                   = "arm64"
        "k8s.io/cluster-autoscaler/node-template/label/instanceOs"                     = "linux"
      }
    }

    # Spot ARM64 Linux instances with 16 vCPUs and 32 GiB memory
    spot_linux_arm64_4xlarge = {
      node_group_name = "mng-spot-linux-arm64-4xlarge"

      ami_type        = "CUSTOM"
      custom_ami_id   = data.aws_ami.zephyr_runner_node_arm64.id
      capacity_type   = "SPOT"
      instance_types  = ["c7g.4xlarge"] # "c6g.4xlarge", "c6gn.4xlarge"

      # Node Group network configuration
      subnet_type = "private" # public or private - Default uses the private subnets used in control plane if you don't pass the "subnet_ids"
      subnet_ids  = []        # Defaults to private subnet-ids used by EKS Control plane. Define your private/public subnets list with comma separated subnet_ids  = ['subnet1','subnet2','subnet3']

      # Node taints
      k8s_taints = [{ key = "spotInstance", value = "true", effect = "NO_SCHEDULE" }]

      # Node label configuration
      k8s_labels = {
        instanceType = "spot"
        instanceSize = "4xlarge"
        instanceArch = "arm64"
        instanceOs   = "linux"
      }

      # NOTE: If we want the node group to scale-down to zero nodes,
      # we need to use a custom launch template and define some additional tags for the ASGs
      desired_size = var.mng_spot_linux_arm64_4xlarge_desired_size
      max_size     = var.mng_spot_linux_arm64_4xlarge_max_size
      min_size     = var.mng_spot_linux_arm64_4xlarge_min_size

      # Block device configuration
      block_device_mappings = [
        {
          device_name = "/dev/xvda"
          volume_type = "gp3"
          volume_size = 200
        }
      ]

      # Launch template configuration
      create_launch_template = true              # false will use the default launch template
      launch_template_os     = "amazonlinux2eks" # amazonlinux2eks or bottlerocket

      # This is so cluster autoscaler can identify which node (using ASGs tags) to scale-down to zero nodes
      additional_tags = {
        "k8s.io/cluster-autoscaler/node-template/label/eks.amazonaws.com/capacityType" = "SPOT"
        "k8s.io/cluster-autoscaler/node-template/label/eks/node_group_name"            = "mng-spot-linux-arm64-4xlarge"
        "k8s.io/cluster-autoscaler/node-template/label/instanceType"                   = "spot"
        "k8s.io/cluster-autoscaler/node-template/label/instanceSize"                   = "4xlarge"
        "k8s.io/cluster-autoscaler/node-template/label/instanceArch"                   = "arm64"
        "k8s.io/cluster-autoscaler/node-template/label/instanceOs"                     = "linux"
      }
    }
  }

  tags = local.tags
}

module "eks_blueprints_kubernetes_addons" {
  source = "./terraform-aws-eks-blueprints/modules/kubernetes-addons"

  eks_cluster_id       = module.eks_blueprints.eks_cluster_id
  eks_cluster_endpoint = module.eks_blueprints.eks_cluster_endpoint
  eks_oidc_provider    = module.eks_blueprints.oidc_provider
  eks_cluster_version  = module.eks_blueprints.eks_cluster_version

  enable_metrics_server                = true
  enable_cluster_autoscaler            = true
  enable_amazon_eks_coredns            = true
  enable_amazon_eks_kube_proxy         = true
  enable_aws_for_fluentbit             = true
  enable_aws_load_balancer_controller  = true
  enable_ingress_nginx                 = true
  enable_cert_manager                  = true
  enable_amazon_eks_aws_ebs_csi_driver = true
  enable_aws_efs_csi_driver            = true
  enable_kubernetes_dashboard          = true
  enable_kube_prometheus_stack         = true
  enable_actions_runner_controller     = true

  # Metrics Server Configurations
  metrics_server_helm_config = {
    version = "3.8.2"
  }

  # Cluster Autoscaler Configurations
  cluster_autoscaler_helm_config = {
    version = "9.21.0"

    set = [
      {
        name  = "extraArgs.new-pod-scale-up-delay"
        value = "30s"
      },
      {
        name  = "extraArgs.scale-down-delay-after-add"
        value = "2m"
      },
      {
        name  = "extraArgs.scale-down-unneeded-time"
        value = "2m"
      },
      {
        name  = "extraArgs.expander"
        value = "priority"
      },
      {
        name  = "expanderPriorities"
        value = <<-EOT
                  100:
                    - .*-spot-.*
                  10:
                    - .*
                EOT
      }
    ]
  }

  # Fluentbit Configurations
  aws_for_fluentbit_create_cw_log_group = true
  aws_for_fluentbit_cw_log_group_name = "/${var.cluster_name}/fluentbit"
  aws_for_fluentbit_cw_log_group_retention = 30

  aws_for_fluentbit_helm_config = {
    version   = "0.1.18"
    namespace = "fluentbit"

    values = [templatefile("${path.module}/helm_values/fluentbit-values.yaml", {
      aws_region           = var.aws_region
      log_group_name       = "/${var.cluster_name}/fluentbit"
      service_account_name = "aws-for-fluent-bit-sa"
    })]
  }

  # AWS Load Balancer Controller Configurations
  aws_load_balancer_controller_helm_config = {
    version = "1.4.3"
  }

  # Cert Manager Configurations
  cert_manager_letsencrypt_ingress_class = "nginx"

  cert_manager_helm_config = {
    version = "v1.9.1"
  }

  # NGINX Ingress Controller Configurations
  ingress_nginx_helm_config = {
    version = "4.0.17"
    values  = [templatefile("${path.module}/helm_values/nginx-values.yaml", {})]
  }

  # AWS EFS CSI Driver Configurations
  aws_efs_csi_driver_helm_config = {
    version = "2.2.6"

    set = [
      {
        name = "controller.deleteAccessPointRootDir"
        value = "true"
      }
    ]
  }

  # Kubernetes Dashboard Configurations
  kubernetes_dashboard_helm_config = {
    version = "5.7.0"
  }

  # Kube Prometheus Stack Configurations
  kube_prometheus_stack_helm_config = {
    version = "36.0.3"

    set_sensitive = [
      {
        name  = "grafana.adminPassword"
        value = var.kube_prometheus_stack_grafana_password
      }
    ]
  }

  # Actions Runner Controller (ARC) Configurations
  actions_runner_controller_helm_config = {
    version = "0.21.1"
    set = [
      {
        name  = "authSecret.create"
        value = "true"
      },
      {
        name  = "authSecret.github_app_id"
        value = var.actions_runner_controller_github_app_id
      },
      {
        name  = "authSecret.github_app_installation_id"
        value = var.actions_runner_controller_github_app_installation_id
      },
      {
        name  = "githubWebhookServer.enabled"
        value = "true"
      },
      {
        name  = "githubWebhookServer.secret.enabled"
        value = "true"
      },
      {
        name  = "githubWebhookServer.secret.create"
        value = "true"
      }
    ]
    set_sensitive = [
      {
        name  = "authSecret.github_app_private_key"
        value = var.actions_runner_controller_github_app_private_key
      },
      {
        name  = "githubWebhookServer.secret.github_webhook_secret_token"
        value = var.actions_runner_controller_webhook_server_secret
      }
    ]
  }

  tags = local.tags
}

#---------------------------------------------------------------
# Virtual Private Network (VPC)
#---------------------------------------------------------------
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.0"

  name = var.cluster_name
  cidr = local.vpc_cidr

  azs             = local.azs
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k + 8)]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  # Manage so we can name
  manage_default_network_acl    = true
  default_network_acl_tags      = { Name = "${var.cluster_name}-default" }
  manage_default_route_table    = true
  default_route_table_tags      = { Name = "${var.cluster_name}-default" }
  manage_default_security_group = true
  default_security_group_tags   = { Name = "${var.cluster_name}-default" }

  public_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = 1
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = 1
  }

  tags = local.tags
}

# VPC S3 endpoint
resource "aws_vpc_endpoint" "s3" {
  vpc_endpoint_type = "Gateway"
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  route_table_ids   = setunion(module.vpc.public_route_table_ids, module.vpc.private_route_table_ids)
}

# VPC ECR endpoint
resource "aws_vpc_endpoint" "ecr" {
  vpc_endpoint_type  = "Interface"
  vpc_id             = module.vpc.vpc_id
  service_name       = "com.amazonaws.${var.aws_region}.ecr.dkr"
  subnet_ids         = module.vpc.private_subnets
  security_group_ids = [
    module.vpc.default_security_group_id,
    module.eks_blueprints.cluster_security_group_id,
    module.eks_blueprints.cluster_primary_security_group_id,
    module.eks_blueprints.worker_node_security_group_id
  ]
}

#---------------------------------------------------------------
# Custom IAM roles for Node Groups
#---------------------------------------------------------------
data "aws_iam_policy_document" "managed_ng_assume_role_policy" {
  statement {
    sid = "EKSWorkerAssumeRole"

    actions = [
      "sts:AssumeRole",
    ]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "managed_ng" {
  name                  = "${var.cluster_name}-managed-node-role"
  description           = "EKS Managed Node group IAM Role"
  assume_role_policy    = data.aws_iam_policy_document.managed_ng_assume_role_policy.json
  path                  = "/"
  force_detach_policies = true
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ]

  tags = local.tags
}

resource "aws_iam_instance_profile" "managed_ng" {
  name = "${var.cluster_name}-managed-node-instance-profile"
  role = aws_iam_role.managed_ng.name
  path = "/"

  lifecycle {
    create_before_destroy = true
  }

  tags = local.tags
}

#---------------------------------------------------------------
# Actions Runner Controller (ARC)
#---------------------------------------------------------------
resource "helm_release" "actions_runner_controller_webhook_server_ingress" {
  name      = "actions-runner-controller-webhook-server-ingress"
  chart     = "${path.module}/actions-runner-controller-webhook-server-ingress"
  version   = "0.1.0"

  set {
    name  = "ingressHost"
    value = var.actions_runner_controller_webhook_server_host
    type  = "string"
  }

  depends_on = [module.eks_blueprints_kubernetes_addons]
}

resource "github_organization_webhook" "actions_runner_controller_github_webhook" {
  configuration {
    url          = "https://${var.actions_runner_controller_webhook_server_host}/"
    content_type = "json"
    secret       = var.actions_runner_controller_webhook_server_secret
    insecure_ssl = false
  }

  active = true
  events = ["workflow_job"]
}

#---------------------------------------------------------------
# eks-admin Administrator Service Account
#---------------------------------------------------------------

resource "kubernetes_service_account" "eks_admin" {
  metadata {
    name      = "eks-admin"
    namespace = "kube-system"
  }
}

resource "kubernetes_cluster_role_binding" "eks_admin" {
  metadata {
    name = "eks-admin"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "eks-admin"
    namespace = "kube-system"
  }

  depends_on = [kubernetes_service_account.eks_admin]
}

#---------------------------------------------------------------
# Zephyr Runner Kubernetes Deployment
#---------------------------------------------------------------

# zephyr-runner Kubernetes Namespace
resource "kubernetes_namespace" "zephyr_runner_namespace" {
  metadata {
    name = "zephyr-runner"
  }

  depends_on = [module.eks_blueprints_kubernetes_addons]
}

# zephyr-runner-linux-x64-xlarge Kubernetes Deployment
data "kubectl_path_documents" "zephyr_runner_linux_x64_xlarge_manifests" {
  pattern = "../../kubernetes/zephyr-runner/zephyr-runner-linux-x64-xlarge.yaml"
}

resource "kubectl_manifest" "zephyr_runner_linux_x64_xlarge_manifest" {
  count      = var.enable_zephyr_runner_linux_x64_xlarge ? length(data.kubectl_path_documents.zephyr_runner_linux_x64_xlarge_manifests.documents) : 0
  yaml_body  = element(data.kubectl_path_documents.zephyr_runner_linux_x64_xlarge_manifests.documents, count.index)
  wait       = true
  depends_on = [kubernetes_namespace.zephyr_runner_namespace]
}

# zephyr-runner-linux-x64-4xlarge Kubernetes Deployment
data "kubectl_path_documents" "zephyr_runner_linux_x64_4xlarge_manifests" {
  pattern = "../../kubernetes/zephyr-runner/zephyr-runner-linux-x64-4xlarge.yaml"
}

resource "kubectl_manifest" "zephyr_runner_linux_x64_4xlarge_manifest" {
  count      = var.enable_zephyr_runner_linux_x64_4xlarge ? length(data.kubectl_path_documents.zephyr_runner_linux_x64_4xlarge_manifests.documents) : 0
  yaml_body  = element(data.kubectl_path_documents.zephyr_runner_linux_x64_4xlarge_manifests.documents, count.index)
  wait       = true
  depends_on = [kubernetes_namespace.zephyr_runner_namespace]
}

# zephyr-runner-linux-arm64-xlarge Kubernetes Deployment
data "kubectl_path_documents" "zephyr_runner_linux_arm64_xlarge_manifests" {
  pattern = "../../kubernetes/zephyr-runner/zephyr-runner-linux-arm64-xlarge.yaml"
}

resource "kubectl_manifest" "zephyr_runner_linux_arm64_xlarge_manifest" {
  count      = var.enable_zephyr_runner_linux_arm64_xlarge ? length(data.kubectl_path_documents.zephyr_runner_linux_arm64_xlarge_manifests.documents) : 0
  yaml_body  = element(data.kubectl_path_documents.zephyr_runner_linux_arm64_xlarge_manifests.documents, count.index)
  wait       = true
  depends_on = [kubernetes_namespace.zephyr_runner_namespace]
}

# zephyr-runner-linux-arm64-4xlarge Kubernetes Deployment
data "kubectl_path_documents" "zephyr_runner_linux_arm64_4xlarge_manifests" {
  pattern = "../../kubernetes/zephyr-runner/zephyr-runner-linux-arm64-4xlarge.yaml"
}

resource "kubectl_manifest" "zephyr_runner_linux_arm64_4xlarge_manifest" {
  count      = var.enable_zephyr_runner_linux_arm64_4xlarge ? length(data.kubectl_path_documents.zephyr_runner_linux_arm64_4xlarge_manifests.documents) : 0
  yaml_body  = element(data.kubectl_path_documents.zephyr_runner_linux_arm64_4xlarge_manifests.documents, count.index)
  wait       = true
  depends_on = [kubernetes_namespace.zephyr_runner_namespace]
}
