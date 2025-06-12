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

data "aws_ami" "amazonlinux2023eks" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amazon-eks-node-al2023-x86_64-standard-${local.cluster_version}-*"]
  }

  owners = ["amazon"]
}

data "aws_availability_zones" "available" {}

locals {
  cluster_version = "1.33"

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = {
    Blueprint  = var.cluster_name
    GithubRepo = "github.com/zephyrproject-rtos/infrastructure"
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

      ami_type               = "AL2023_x86_64_STANDARD" # Available options -> AL2023_X86_64_STANDARD, AL2023_ARM_64_STANDARD, CUSTOM
      release_version        = ""              # Enter AMI release version to deploy the latest AMI released by AWS. Used only when you specify ami_type
      capacity_type          = "ON_DEMAND"     # ON_DEMAND or SPOT
      instance_types         = ["c6a.2xlarge"] # List of instances used only for SPOT type
      format_mount_nvme_disk = true            # format and mount NVMe disks ; default to false

      # Launch template configuration
      create_launch_template = false           # false will use the default launch template
      # launch_template_os     = "amazonlinux2eks" # amazonlinux2eks or bottlerocket

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

  # Metrics Server Configurations
  metrics_server_helm_config = {
    version = "3.8.2"
  }

  # Cluster Autoscaler Configurations
  cluster_autoscaler_image_tag = "v1.32.1"
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

  # AWS EBS CSI Driver Configurations
  amazon_eks_aws_ebs_csi_driver_config = {
    # NOTE: Let EKS blueprints choose an adequate version.
    # addon_version = "v1.44.0-eksbuild.1"
  }

  # AWS EFS CSI Driver Configurations
  aws_efs_csi_driver_helm_config = {
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

  tags = local.tags
}

#---------------------------------------------------------------
# Virtual Private Network (VPC)
#---------------------------------------------------------------
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

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
# Kubernetes Storage Class
#---------------------------------------------------------------

# NOTE: gp2 storage class is created by default.

# gp3
resource "kubernetes_storage_class_v1" "gp3" {
  metadata {
    name = "gp3"
  }

  storage_provisioner    = "ebs.csi.aws.com"
  allow_volume_expansion = true
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"
  parameters = {
    encrypted = true
    fsType    = "ext4"
    type      = "gp3"
  }

  depends_on = [
    module.eks_blueprints_kubernetes_addons
  ]
}

# sc1
resource "kubernetes_storage_class_v1" "sc1" {
  metadata {
    name = "sc1"
  }

  storage_provisioner    = "ebs.csi.aws.com"
  allow_volume_expansion = true
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"
  parameters = {
    encrypted = true
    fsType    = "ext4"
    type      = "sc1"
  }

  depends_on = [
    module.eks_blueprints_kubernetes_addons
  ]
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

#-------------------
# OpenEBS Deployment
#-------------------

resource "helm_release" "openebs" {
  name       = "openebs"
  namespace  = "openebs"
  create_namespace = true
  repository = "https://openebs.github.io/charts"
  chart      = "openebs"
  version    = "3.10.0"
  values     = ["${file("../../kubernetes/zephyr-runner-v2/aws/aws-openebs/values.yaml")}"]
  depends_on = [module.eks_blueprints_kubernetes_addons]
}

#---------------------------------------------------------------
# Elastic Cloud on Kubernetes (ECK) Stack Deployment
#---------------------------------------------------------------

# ECK Operator
resource "helm_release" "elastic_operator" {
  name       = "elastic-operator"
  repository = "https://helm.elastic.co"
  chart      = "eck-operator"
  version    = "2.5.0"

  namespace  = "elastic-system"
  create_namespace = true

  depends_on = [module.eks_blueprints_kubernetes_addons]
}
