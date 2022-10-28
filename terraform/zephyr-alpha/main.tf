provider "aws" {
  region = local.region
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
}

provider "helm" {
  kubernetes {
    host                   = module.eks_blueprints.eks_cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks_blueprints.eks_cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
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

data "aws_availability_zones" "available" {}

locals {
  name   = "zephyr-alpha"
  region = "us-east-2"

  cluster_version = "1.23"

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = {
    Blueprint  = local.name
    GithubRepo = "github.com/zephyrproject-rtos/infrastructure-private"
  }
}

#---------------------------------------------------------------
# EKS Blueprints
#---------------------------------------------------------------
module "eks_blueprints" {
  source = "./terraform-aws-eks-blueprints"

  cluster_name    = local.name
  cluster_version = local.cluster_version

  # AWS identity mapping
  map_users = [
    {
      userarn  = "arn:aws:iam::724087766192:user/terraform-cloud"
      username = "terraform-cloud"
      groups   = ["system:masters"]
    },
    {
      userarn  = "arn:aws:iam::724087766192:user/stephanosio"
      username = "stephanosio"
      groups   = ["system:masters"]
    }
  ]

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
    # On-demand general-purpose instances with 8 vCPUs and 16GiB memory 
    od_8vcpu_16mem = {
      # Node Group configuration
      node_group_name = "mng-od-8vcpu-16mem" # Max 40 characters for node group name

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
        InstanceType = "on-demand"
      }

      # Node Group scaling configuration
      desired_size = 1
      max_size     = 10
      min_size     = 1

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

    # Spot instances with 4 vCPU and 8 GiB memory
    spot_4vcpu_8mem = {
      node_group_name = "mng-spot-4vcpu-8mem"
      capacity_type   = "SPOT"
      instance_types  = ["c5a.xlarge"]

      # Node Group network configuration
      subnet_type = "private" # public or private - Default uses the private subnets used in control plane if you don't pass the "subnet_ids"
      subnet_ids  = []        # Defaults to private subnet-ids used by EKS Control plane. Define your private/public subnets list with comma separated subnet_ids  = ['subnet1','subnet2','subnet3']

      # Node taints
      k8s_taints = [{ key = "spotInstance", value = "true", effect = "NO_SCHEDULE" }]

      # Node label configuration
      k8s_labels = {
        InstanceType = "spot"
      }

      # NOTE: If we want the node group to scale-down to zero nodes,
      # we need to use a custom launch template and define some additional tags for the ASGs
      max_size = 100
      min_size = 0

      # Block device configuration
      block_device_mappings = [
        {
          device_name = "/dev/xvda"
          volume_type = "gp3"
          volume_size = 100
        }
      ]

      # Launch template configuration
      create_launch_template = true              # false will use the default launch template
      launch_template_os     = "amazonlinux2eks" # amazonlinux2eks or bottlerocket

      # This is so cluster autoscaler can identify which node (using ASGs tags) to scale-down to zero nodes
      additional_tags = {
        "k8s.io/cluster-autoscaler/node-template/label/eks.amazonaws.com/capacityType" = "SPOT"
        "k8s.io/cluster-autoscaler/node-template/label/eks/node_group_name"            = "mng-spot-4vcpu-8mem"
      }
    }

    # Spot instances with 16 vCPUs and 32 GiB memory
    spot_16vcpu_32mem = {
      node_group_name = "mng-spot-16vcpu-32mem"
      capacity_type   = "SPOT"
      instance_types  = ["c5a.4xlarge"]

      # Node Group network configuration
      subnet_type = "private" # public or private - Default uses the private subnets used in control plane if you don't pass the "subnet_ids"
      subnet_ids  = []        # Defaults to private subnet-ids used by EKS Control plane. Define your private/public subnets list with comma separated subnet_ids  = ['subnet1','subnet2','subnet3']

      # Node taints
      k8s_taints = [{ key = "spotInstance", value = "true", effect = "NO_SCHEDULE" }]

      # Node label configuration
      k8s_labels = {
        InstanceType = "spot"
      }

      # NOTE: If we want the node group to scale-down to zero nodes,
      # we need to use a custom launch template and define some additional tags for the ASGs
      max_size = 100
      min_size = 0

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
        "k8s.io/cluster-autoscaler/node-template/label/eks/node_group_name"            = "mng-spot-16vcpu-32mem"
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
  enable_aws_load_balancer_controller  = true
  enable_ingress_nginx                 = true
  enable_cert_manager                  = true
  enable_amazon_eks_aws_ebs_csi_driver = true
  enable_aws_efs_csi_driver            = true
  enable_actions_runner_controller     = true

  # Cluster Autoscaler Configurations
  cluster_autoscaler_helm_config = {
    set = [
      {
        name  = "extraArgs.expander"
        value = "priority"
      },
      {
        name  = "expanderPriorities"
        value = <<-EOT
                  100:
                    - .*-spot-4vcpu-8mem.*
                  90:
                    - .*-spot-16vcpu-32mem.*
                  10:
                    - .*
                EOT
      }
    ]
  }

  # NGINX Ingress Controller Configurations
  ingress_nginx_helm_config = {
    version = "4.0.17"
    values  = [templatefile("${path.module}/nginx-values.yaml", {})]
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
      }
    ]
    set_sensitive = [
      {
        name  = "authSecret.github_app_private_key"
        value = var.actions_runner_controller_github_app_private_key
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

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k + 8)]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  # Manage so we can name
  manage_default_network_acl    = true
  default_network_acl_tags      = { Name = "${local.name}-default" }
  manage_default_route_table    = true
  default_route_table_tags      = { Name = "${local.name}-default" }
  manage_default_security_group = true
  default_security_group_tags   = { Name = "${local.name}-default" }

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.name}" = "shared"
    "kubernetes.io/role/elb"              = 1
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.name}" = "shared"
    "kubernetes.io/role/internal-elb"     = 1
  }

  tags = local.tags
}

# VPC S3 endpoint
resource "aws_vpc_endpoint" "s3" {
  vpc_endpoint_type = "Gateway"
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.us-east-2.s3"
  route_table_ids   = setunion(module.vpc.public_route_table_ids, module.vpc.private_route_table_ids)
}

# VPC ECR endpoint
resource "aws_vpc_endpoint" "ecr" {
  vpc_endpoint_type  = "Interface"
  vpc_id             = module.vpc.vpc_id
  service_name       = "com.amazonaws.us-east-2.ecr.dkr"
  subnet_ids         = module.vpc.private_subnets
  security_group_ids = [
    module.vpc.default_security_group_id,
    module.eks_blueprints.cluster_security_group_id,
    module.eks_blueprints.cluster_primary_security_group_id,
    module.eks_blueprints.worker_node_security_group_id
  ]
}

#---------------------------------------------------------------
# Elastic File System (EFS)
#---------------------------------------------------------------
resource "aws_efs_file_system" "efs" {
  creation_token = "efs"
  encrypted      = true

  tags = local.tags
}

resource "aws_efs_mount_target" "efs_mt" {
  count = length(module.vpc.private_subnets)

  file_system_id  = aws_efs_file_system.efs.id
  subnet_id       = module.vpc.private_subnets[count.index]
  security_groups = [aws_security_group.efs.id]
}

resource "aws_security_group" "efs" {
  name        = "${local.name}-efs"
  description = "Allow inbound NFS traffic from private subnets of the VPC"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "Allow NFS 2049/tcp"
    cidr_blocks = module.vpc.private_subnets_cidr_blocks
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
  }

  tags = local.tags
}

resource "kubernetes_storage_class" "efs_sc" {
  metadata {
    name = "efs"
  }

  storage_provisioner = "efs.csi.aws.com"
  reclaim_policy      = "Delete"

  parameters = {
    provisioningMode = "efs-ap"
    fileSystemId     = aws_efs_file_system.efs.id
    directoryPerms   = "700"
    uid              = "1000"
    gid              = "1000"
    basePath         = "/dynamic"
  }
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
  name                  = "managed-node-role"
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
  name = "managed-node-instance-profile"
  role = aws_iam_role.managed_ng.name
  path = "/"

  lifecycle {
    create_before_destroy = true
  }

  tags = local.tags
}

#---------------------------------------------------------------
# Custom Kubernetes Resources
#---------------------------------------------------------------

# Let's Encrypt Certificate Issuers
resource "kubectl_manifest" "cert_manager_letsencrypt_production" {
  yaml_body  = templatefile("./letsencrypt-production-clusterissuer.yaml", {})
  wait       = true
  depends_on = [module.eks_blueprints_kubernetes_addons]
}

resource "kubectl_manifest" "cert_manager_letsencrypt_staging" {
  yaml_body  = templatefile("./letsencrypt-staging-clusterissuer.yaml", {})
  wait       = true
  depends_on = [module.eks_blueprints_kubernetes_addons]
}
