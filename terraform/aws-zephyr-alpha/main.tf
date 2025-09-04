provider "kubectl" {
  host                   = module.zephyr_aws_blueprints.eks_cluster_endpoint
  cluster_ca_certificate = module.zephyr_aws_blueprints.eks_cluster_ca_certificate
  token                  = module.zephyr_aws_blueprints.eks_cluster_auth_token
  load_config_file       = false
}

provider "helm" {
  kubernetes {
    host                   = module.zephyr_aws_blueprints.eks_cluster_endpoint
    cluster_ca_certificate = module.zephyr_aws_blueprints.eks_cluster_ca_certificate
    token                  = module.zephyr_aws_blueprints.eks_cluster_auth_token
  }
}

provider "aws" {
  region = "us-east-1"
}

# AWS Secrets Manager terraform-zephyr-secrets Secret
data "aws_secretsmanager_secret_version" "terraform-zephyr-secrets" {
  secret_id = "terraform-zephyr-secrets"
}

locals {
  zephyr_secrets = jsondecode(data.aws_secretsmanager_secret_version.terraform-zephyr-secrets.secret_string)
}

# Zephyr AWS Blueprints
module "zephyr_aws_blueprints" {
  source = "../zephyr-aws-blueprints"

  cluster_name = "zephyr-alpha"
  aws_region   = "us-east-2"

  aws_auth_map_users = [
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

  mng_od_linux_x64_2xlarge_min_size     = 2
  mng_od_linux_x64_2xlarge_max_size     = 4
  mng_od_linux_x64_2xlarge_desired_size = 2

  github_organization = "zephyrproject-rtos"

  kube_prometheus_stack_grafana_password = local.zephyr_secrets.kube_prometheus_stack_grafana_password
}
