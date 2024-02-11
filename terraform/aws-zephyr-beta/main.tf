provider "helm" {
  kubernetes {
    host                   = module.zephyr_aws_blueprints.eks_cluster_endpoint
    cluster_ca_certificate = module.zephyr_aws_blueprints.eks_cluster_ca_certificate
    token                  = module.zephyr_aws_blueprints.eks_cluster_auth_token
  }
}

# Local Variables
locals {
  arc_version = "0.8.2"
}

# HashiCorp Vault Secrets zephyr-secrets Vault
data "hcp_vault_secrets_app" "zephyr_secrets" {
  app_name = "zephyr-secrets"
}

# Zephyr AWS Blueprints
module "zephyr_aws_blueprints" {
  source = "../zephyr-aws-blueprints"

  cluster_name = "zephyr-beta"
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
  mng_od_linux_x64_2xlarge_max_size     = 2
  mng_od_linux_x64_2xlarge_desired_size = 2

  mng_spot_linux_x64_xlarge_min_size     = 0
  mng_spot_linux_x64_xlarge_max_size     = 100
  mng_spot_linux_x64_xlarge_desired_size = 1

  mng_spot_linux_x64_4xlarge_min_size     = 0
  mng_spot_linux_x64_4xlarge_max_size     = 100
  mng_spot_linux_x64_4xlarge_desired_size = 1

  mng_spot_linux_arm64_xlarge_min_size     = 0
  mng_spot_linux_arm64_xlarge_max_size     = 100
  mng_spot_linux_arm64_xlarge_desired_size = 1

  mng_spot_linux_arm64_4xlarge_min_size     = 0
  mng_spot_linux_arm64_4xlarge_max_size     = 100
  mng_spot_linux_arm64_4xlarge_desired_size = 1

  github_organization = "zephyrproject-rtos"

  kube_prometheus_stack_grafana_password = data.hcp_vault_secrets_app.zephyr_secrets.secrets["kube_prometheus_stack_grafana_password"]

  actions_runner_controller_github_app_id              = nonsensitive(data.hcp_vault_secrets_app.zephyr_secrets.secrets["test_runner_github_app_id"])
  actions_runner_controller_github_app_installation_id = nonsensitive(data.hcp_vault_secrets_app.zephyr_secrets.secrets["test_runner_github_app_installation_id"])
  actions_runner_controller_github_app_private_key     = data.hcp_vault_secrets_app.zephyr_secrets.secrets["test_runner_github_app_private_key"]

  actions_runner_controller_v2_version                    = local.arc_version
  actions_runner_controller_v2_github_app_id              = data.hcp_vault_secrets_app.zephyr_secrets.secrets["test_runner_github_app_id"]
  actions_runner_controller_v2_github_app_installation_id = data.hcp_vault_secrets_app.zephyr_secrets.secrets["test_runner_github_app_installation_id"]
  actions_runner_controller_v2_github_app_private_key     = data.hcp_vault_secrets_app.zephyr_secrets.secrets["test_runner_github_app_private_key"]

  enable_zephyr_runner_linux_x64_xlarge = false
  enable_zephyr_runner_linux_x64_4xlarge = false
  enable_zephyr_runner_linux_arm64_xlarge = false
  enable_zephyr_runner_linux_arm64_4xlarge = false
}

# Actions Runner Controller (ARC) Runner Scale Sets
## test-runner-v2-linux-x64-4xlarge-aws Runner Scale Set Deployment
resource "helm_release" "test_runner_v2_linux_x64_4xlarge_aws" {
  name       = "test-runner-v2-linux-x64-4xlarge-aws"
  namespace  = "arc-runners"
  chart      = "oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set"
  version    = local.arc_version
  values     = ["${file("../../kubernetes/zephyr-runner-v2/aws/test-runner-scale-sets/test-runner-v2-linux-x64-4xlarge-aws/values.yaml")}"]
  depends_on = [module.zephyr_aws_blueprints.actions_runner_controller]
}
