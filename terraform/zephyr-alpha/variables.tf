variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-2"
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
  default     = "grafana"
}

variable "actions_runner_controller_github_app_id" {
  description = "GitHub app ID for Actions Runner Controller"
  type        = string
  default     = ""
}

variable "actions_runner_controller_github_app_installation_id" {
  description = "GitHub app installation ID for Actions Runner Controller"
  type        = string
  default     = ""
}

variable "actions_runner_controller_github_app_private_key" {
  description = "GitHub app private key for Actions Runner Controller"
  type        = string
  sensitive   = true
  default     = ""
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
  default     = "testwebhookserversecret1234"
}
