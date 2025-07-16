locals {
  team_members_path = "team/team-members"
  team_members_files = {
    for file in fileset(local.team_members_path, "*.csv") :
    trimsuffix(file, ".csv") => csvdecode(file("${local.team_members_path}/${file}"))
  }
}

resource "github_team_members" "members" {
  for_each = local.team_members_files

  team_id = github_team.all[each.key].id

  dynamic "members" {
    for_each = local.team_members_files[each.key]

    content {
      username = members.value.username
      role = members.value.role
    }
  }
}
