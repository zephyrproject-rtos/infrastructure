variable "cluster_name" {
  description = "Cluster name"
  type        = string
  default     = "zephyr-alpha"
}

variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-2"
}

variable "aws_auth_map_users" {
  description = "Additional IAM users to add to the aws-auth ConfigMap"
  type = list(object({
    userarn  = string
    username = string
    groups   = list(string)
  }))
  default = []
}

variable "mng_od_8vcpu_16mem_min_size" {
  description = "Minimum number of nodes for 8 vCPU 16 GiB memory on-demand instance managed node group"
  type        = number
  default     = 1
}

variable "mng_od_8vcpu_16mem_max_size" {
  description = "Maximum number of nodes for 8 vCPU 16 GiB memory on-demand instance managed node group"
  type        = number
  default     = 10
}

variable "mng_od_8vcpu_16mem_desired_size" {
  description = "Desired number of nodes for 8 vCPU 16 GiB memory on-demand instance managed node group"
  type        = number
  default     = 2
}

variable "mng_spot_4vcpu_8mem_min_size" {
  description = "Minimum number of nodes for 4 vCPU 8 GiB memory spot instance managed node group"
  type        = number
  default     = 0
}

variable "mng_spot_4vcpu_8mem_max_size" {
  description = "Maximum number of nodes for 4 vCPU 8 GiB memory spot instance managed node group"
  type        = number
  default     = 100
}

variable "mng_spot_4vcpu_8mem_desired_size" {
  description = "Desired number of nodes for 4 vCPU 8 GiB memory spot instance managed node group"
  type        = number
  default     = 1
}

variable "mng_spot_16vcpu_32mem_min_size" {
  description = "Minimum number of nodes for 16 vCPU 32 GiB memory spot instance managed node group"
  type        = number
  default     = 0
}

variable "mng_spot_16vcpu_32mem_max_size" {
  description = "Maximum number of nodes for 16 vCPU 32 GiB memory spot instance managed node group"
  type        = number
  default     = 100
}

variable "mng_spot_16vcpu_32mem_desired_size" {
  description = "Desired number of nodes for 16 vCPU 32 GiB memory spot instance managed node group"
  type        = number
  default     = 1
}

variable "github_organization" {
  description = "GitHub organization name"
  type        = string
  default     = "zephyrproject-rtos"
}

variable "kube_prometheus_stack_grafana_password" {
  description = "Grafana password for Kube Prometheus Stack"
  type        = string
  sensitive   = true
}

variable "actions_runner_controller_github_app_id" {
  description = "GitHub app ID for Actions Runner Controller"
  type        = string
}

variable "actions_runner_controller_github_app_installation_id" {
  description = "GitHub app installation ID for Actions Runner Controller"
  type        = string
}

variable "actions_runner_controller_github_app_private_key" {
  description = "GitHub app private key for Actions Runner Controller"
  type        = string
  sensitive   = true
}

variable "actions_runner_controller_webhook_server_host" {
  description = "Webhook server host for Actions Runner Controller"
  type        = string
  default     = "webhook.arc-alpha.ci.zephyrproject.io"
}

variable "actions_runner_controller_webhook_server_secret" {
  description = "Webhook server secret for Actions Runner Controller"
  type        = string
  sensitive   = true
}

variable "enable_zephyr_runner_linux_x64_xlarge" {
  description = "Enable Zephyr Runner linux-x64-xlarge"
  type        = bool
  default     = false
}

variable "enable_zephyr_runner_linux_x64_4xlarge" {
  description = "Enable Zephyr Runner linux-x64-4xlarge"
  type        = bool
  default     = false
}
