terraform {
  cloud {
    organization = "zephyrproject-rtos"
    workspaces {
      name = "zephyr-beta"
    }
  }
}
