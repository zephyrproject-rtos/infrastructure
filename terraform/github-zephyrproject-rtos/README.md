# github-zephyrproject-rtos

## Overview

This directory contains the Terraform manifests that define the resources in the
GitHub `zephyrproject-rtos` organisation.

The resources defined in this directory include GitHub members, repositories and
teams.

## Modules

### repository

The `repository` module defines the repository configurations and collaborators
for the managed GitHub repositories in the `zephyrproject-rtos` organisation.

The configurations managed by the `repository` module include:

* Repository name and description
* Features (issues, discussions, projects, wiki)
* Default branch
* Pull request merge methods
* Repository collaborators
* Branch protection rules
* Rulesets
* Actions permissions

In order to synchronise the repository configurations, run the following
command:

```
terraform apply -target=module.repository
```

### team

The `team` module defines the GitHub teams and their members in the
`zephyrproject-rtos` organisation.

In order to synchronise the team configurations, run the following command:

```
terraform apply -taget=module.team
```

Note that the team members who have not accepted the invitation are considered
"not-applied" and will show up as required changes during `terraform apply`.
