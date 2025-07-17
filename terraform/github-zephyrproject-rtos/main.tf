# GitHub provider
provider "github" {
  owner = "zephyrproject-rtos"
}

# 'team' module defines GitHub teams and their members
module "team" {
  source = "./team"
}

# 'repository' module defines GitHub repository configurations and
# collaborators
module "repository" {
  source = "./repository"
}
