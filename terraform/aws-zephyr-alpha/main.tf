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

# HashiCorp Vault Secrets zephyr-secrets Vault
data "hcp_vault_secrets_app" "zephyr_secrets" {
  app_name = "zephyr-secrets"
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

  mng_od_linux_x64_2xlarge_min_size     = 1
  mng_od_linux_x64_2xlarge_max_size     = 4
  mng_od_linux_x64_2xlarge_desired_size = 2

  github_organization = "zephyrproject-rtos"

  kube_prometheus_stack_grafana_password = data.hcp_vault_secrets_app.zephyr_secrets.secrets["kube_prometheus_stack_grafana_password"]
}
