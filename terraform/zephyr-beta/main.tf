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

  mng_od_8vcpu_16mem_min_size     = 1
  mng_od_8vcpu_16mem_max_size     = 2
  mng_od_8vcpu_16mem_desired_size = 1

  mng_spot_4vcpu_8mem_min_size     = 0
  mng_spot_4vcpu_8mem_max_size     = 100
  mng_spot_4vcpu_8mem_desired_size = 1

  mng_spot_16vcpu_32mem_min_size     = 0
  mng_spot_16vcpu_32mem_max_size     = 100
  mng_spot_16vcpu_32mem_desired_size = 1

  github_organization = "zephyrproject-rtos"

  kube_prometheus_stack_grafana_password = var.kube_prometheus_stack_grafana_password

  actions_runner_controller_github_app_id              = "256098"
  actions_runner_controller_github_app_installation_id = "30737086"
  actions_runner_controller_github_app_private_key     = var.actions_runner_controller_github_app_private_key

  actions_runner_controller_webhook_server_host   = "webhook.arc-beta.ci.zephyrproject.io"
  actions_runner_controller_webhook_server_secret = var.actions_runner_controller_webhook_server_secret

  enable_zephyr_runner_repo_cache = false
}
