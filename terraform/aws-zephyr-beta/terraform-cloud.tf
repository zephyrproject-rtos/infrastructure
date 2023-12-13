terraform {
  cloud {
    organization = "zephyrproject-rtos"
    workspaces {
      name = "aws-zephyr-beta"
    }
  }
}
