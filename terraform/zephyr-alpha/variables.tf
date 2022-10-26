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
