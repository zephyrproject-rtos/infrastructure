variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-2"
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
