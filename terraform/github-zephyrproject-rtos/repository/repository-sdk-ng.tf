resource "github_repository" "sdk-ng" {
  name = "sdk-ng"
  description = "Zephyr SDK (Toolchains, Development Tools)"

  has_issues = true
  has_discussions = true
  has_projects = true
  has_wiki = true
  has_downloads = true

  allow_merge_commit = false
  allow_squash_merge = false
  allow_rebase_merge = true
  allow_auto_merge = false
  allow_update_branch = true
}

# Default branch
resource "github_branch_default" "sdk-ng" {
  repository = github_repository.sdk-ng.name
  branch = github_branch.sdk-ng-main.branch
}

# Actions
resource "github_actions_repository_permissions" "sdk-ng" {
  allowed_actions = "all"
  repository = github_repository.sdk-ng.name
}

# Branches
resource "github_branch" "sdk-ng-main" {
  branch = "main"
  repository = github_repository.sdk-ng.name
}

# Branch Protection Rules
resource "github_branch_protection" "sdk-ng-main" {
  pattern = "main"

  enforce_admins = false

  require_conversation_resolution = false
  require_signed_commits = false
  required_linear_history = true
  lock_branch = false

  allows_force_pushes = false
  allows_deletions = false

  required_pull_request_reviews {
    required_approving_review_count = 1
    dismiss_stale_reviews = false
    require_code_owner_reviews = false
    require_last_push_approval = false
  }

  required_status_checks {
    strict = false
    contexts = ["Test Result"]
  }

  restrict_pushes {
    blocks_creations = true
    push_allowances = [
      # Only allow users with "Maintain" access level to push.
    ]
  }

  repository_id = github_repository.sdk-ng.node_id
}

resource "github_branch_protection" "sdk-ng-vx-branch" {
  pattern = "v*-branch"

  require_conversation_resolution = false
  require_signed_commits = false
  required_linear_history = true
  lock_branch = false
  enforce_admins = false

  allows_force_pushes = false
  allows_deletions = false

  required_pull_request_reviews {
    required_approving_review_count = 1
    dismiss_stale_reviews = false
    require_code_owner_reviews = false
    require_last_push_approval = false
  }

  required_status_checks {
    strict = false
    contexts = ["Test Result"]
  }

  restrict_pushes {
    blocks_creations = true
    push_allowances = [
      # Only allow users with "Maintain" access level to push.
    ]
  }

  repository_id = github_repository.sdk-ng.node_id
}

# Rulesets
resource "github_repository_ruleset" "sdk-ng-block-release-tag-modification" {
  name = "Block release tag modification"
  target = "tag"
  enforcement = "active"

  conditions {
    ref_name {
      include = ["refs/tags/v*"]
      exclude = []
    }
  }

  rules {
    # Restrict creations
    creation = false
    # Restrict updates
    update = true
    # Restrict deletions
    deletion = true
    # Require linear history
    required_linear_history = false
    # Require signed commits
    required_signatures = false
    # Block force pushes
    non_fast_forward = true
  }

  repository = github_repository.sdk-ng.name
}

resource "github_repository_ruleset" "sdk-ng-restrict-release-tag-creation" {
  name = "Restrict release tag creation"
  target = "tag"
  enforcement = "active"

  conditions {
    ref_name {
      include = ["refs/tags/v*"]
      exclude = []
    }
  }

  rules {
    # Restrict creations
    creation = true
    # Restrict updates
    update = false
    # Restrict deletions
    deletion = false
    # Require linear history
    required_linear_history = false
    # Require signed commits
    required_signatures = false
    # Block force pushes
    non_fast_forward = false
  }

  bypass_actors {
    actor_type = "RepositoryRole"
    actor_id = "2" # Maintain
    bypass_mode = "always"
  }

  bypass_actors {
    actor_type = "RepositoryRole"
    actor_id = "5" # Repository admin
    bypass_mode = "always"
  }

  repository = github_repository.sdk-ng.name
}
