terraform {
  cloud {
    organization = "zephyrproject-rtos"
    workspaces {
      name = "hzr-ci-main"
    }
  }
}
