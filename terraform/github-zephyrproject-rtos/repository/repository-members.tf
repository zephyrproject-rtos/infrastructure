locals {
  repository_members_path = "repository/repository-members"
  repository_members_files = {
    for file in fileset(local.repository_members_path, "*.csv") :
    trimsuffix(file, ".csv") => csvdecode(file("${local.repository_members_path}/${file}"))
  }
  global_teams = [
    "infrastructure"
  ]
}

resource "github_repository_collaborators" "members" {
  for_each = local.repository_members_files

  repository = each.key

  dynamic "user" {
    for_each = {
      for u in local.repository_members_files[each.key] :
      u.id => u if u.type == "user"
    }

    content {
      username = user.value.id
      permission = user.value.permission
    }
  }

  dynamic "team" {
    for_each = {
      for t in local.repository_members_files[each.key] :
      t.id => t if t.type == "team"
    }

    content {
      team_id = team.value.id
      permission = team.value.permission
    }
  }

  dynamic "ignore_team" {
    for_each = local.global_teams

    content {
      team_id = ignore_team.value
    }
  }
}
