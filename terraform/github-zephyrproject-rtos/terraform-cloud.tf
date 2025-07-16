terraform {
  cloud {
    organization = "zephyrproject-rtos"
    workspaces {
      name = "github-zephyrproject-rtos"
    }
  }
}
