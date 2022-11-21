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
  mng_od_linux_x64_2xlarge_max_size     = 2
  mng_od_linux_x64_2xlarge_desired_size = 2

  mng_spot_linux_x64_xlarge_min_size     = 0
  mng_spot_linux_x64_xlarge_max_size     = 100
  mng_spot_linux_x64_xlarge_desired_size = 1

  mng_spot_linux_x64_4xlarge_min_size     = 0
  mng_spot_linux_x64_4xlarge_max_size     = 100
  mng_spot_linux_x64_4xlarge_desired_size = 1

  github_organization = "zephyrproject-rtos"

  kube_prometheus_stack_grafana_password = var.kube_prometheus_stack_grafana_password

  actions_runner_controller_github_app_id              = "250859"
  actions_runner_controller_github_app_installation_id = "30394780"
  actions_runner_controller_github_app_private_key     = var.actions_runner_controller_github_app_private_key

  actions_runner_controller_webhook_server_host   = "webhook.arc-alpha.ci.zephyrproject.io"
  actions_runner_controller_webhook_server_secret = var.actions_runner_controller_webhook_server_secret

  enable_zephyr_runner_linux_x64_xlarge = true
  enable_zephyr_runner_linux_x64_4xlarge = true
}
