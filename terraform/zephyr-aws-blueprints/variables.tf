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

variable "mng_od_linux_x64_2xlarge_min_size" {
  description = "Minimum number of nodes for Linux x86-64 2xlarge on-demand instance managed node group"
  type        = number
  default     = 1
}

variable "mng_od_linux_x64_2xlarge_max_size" {
  description = "Maximum number of nodes for Linux x86-64 2xlarge on-demand instance managed node group"
  type        = number
  default     = 10
}

variable "mng_od_linux_x64_2xlarge_desired_size" {
  description = "Desired number of nodes for Linux x86-64 2xlarge on-demand instance managed node group"
  type        = number
  default     = 2
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
