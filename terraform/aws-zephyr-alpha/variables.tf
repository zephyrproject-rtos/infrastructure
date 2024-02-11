variable "kube_prometheus_stack_grafana_password" {
  description = "Grafana password for Kube Prometheus Stack"
  type        = string
  sensitive   = true
}

variable "actions_runner_controller_github_app_private_key" {
  description = "GitHub app private key for Actions Runner Controller"
  type        = string
  sensitive   = true
}
