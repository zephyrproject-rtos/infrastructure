terraform {
  cloud {
    organization = "zephyrproject-rtos"
    workspaces {
      name = "cnx-zephyr-test"
    }
  }
}
