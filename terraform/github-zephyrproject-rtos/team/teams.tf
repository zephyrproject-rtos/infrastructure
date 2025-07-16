locals {
  teams = {
    # Keep this list alphanumerically sorted.
    "bluetooth-sig" = {
      "name" = "bluetooth-sig"
      "description" = "Approved Bluetooth SIG members"
      "privacy" = "secret"
    }
    "board" = {
      "name" = "board"
      "description" = "Zephyr Board members"
      "privacy" = "secret"
    }
    "collaborators" = {
      "name" = "collaborators"
      "description" = "Highly involved Contributors in one or more areas. See https://docs.zephyrproject.org/latest/project/project_roles.html#collaborator"
      "privacy" = "closed"
    }
    "contributors" = {
      "name" = "contributors"
      "description" = "Contributors with Triage permission level. See https://docs.zephyrproject.org/latest/project/project_roles.html#contributor"
      "privacy" = "closed"
    }
    "infrastructure" = {
      "name" = "infrastructure"
      "description" = "Project infrastructure maintainers"
      "privacy" = "closed"
    }
    "kconfiglib" = {
      "name" = "kconfiglib"
      "description" = "Kconfiglib maintainers"
      "privacy" = "closed"
    }
    "maintainers" = {
      "name" = "maintainers"
      "description" = "Lead Collaborators on an area identified by the TSC. See https://docs.zephyrproject.org/latest/project/project_roles.html#maintainer"
      "privacy" = "closed"
    }
    "marketing" = {
      "name" = "marketing"
      "description" = "Marketing Committee"
      "privacy" = "closed"
    }
    "release" = {
      "name" = "release"
      "description" = "Release Team"
      "privacy" = "closed"
    }
    "safety" = {
      "name" = "safety"
      "description" = "Safety Committee"
      "privacy" = "closed"
    }
    "sdk" = {
      "name" = "sdk"
      "description" = "SDK Maintainers"
      "privacy" = "closed"
    }
    "security" = {
      "name" = "security"
      "description" = "Security Committee"
      "privacy" = "closed"
    }
    "testing" = {
      "name" = "testing"
      "description" = "Testing Working Group"
      "privacy" = "closed"
    }
    "tsc" = {
      "name" = "tsc"
      "description" = "Technical Steering Committee"
      "privacy" = "closed"
    }
    "west" = {
      "name" = "west"
      "description" = "West maintainers"
      "privacy" = "closed"
    }
  }
}

resource "github_team" "all" {
  for_each = {
    for team in local.teams :
    team.name => team
  }

  name = each.value.name
  description = each.value.description
  privacy = each.value.privacy
}
