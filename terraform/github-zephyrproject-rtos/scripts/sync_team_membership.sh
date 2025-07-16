#!/usr/bin/env bash

# This scripts generates the 'collaborators' and 'maintainers' GitHub team
# member list files from the Zephyr MAINTAINERS.yml file.

set -e

usage()
{
	echo "Usage: $(basename $0) maintainers_file manifest_path"
}

# Validate and prase arguments
if [ "$1" == "" ]; then
  usage
  echo
  echo "maintainers_file must be specified."
  exit 1
elif [ "$2" == "" ]; then
  usage
  echo
	echo "manifest_path must be specified."
  exit 1
fi

maintainers_file=$1
manifest_path=$2

if [ ! -f "${maintainers_file}" ]; then
  echo "'${maintainers_file}' does not exist."
  exit 2
fi

if [ ! -d "${manifest_path}" ]; then
  echo "'${manifest_path}' is not a valid directory."
fi

# Read and validate maintainers file.
maintainers_data=$(<${maintainers_file})

echo "${maintainers_data}" | yq &> /dev/null || (
  echo "'${maintainers_file}' is not a valid YAML file."
  exit 10
)

# Get the list of all collaborators
all_collaborators=$(echo "${maintainers_data}" | yq -r '.[].collaborators.[]')
all_collaborators=$(echo "${all_collaborators}" | sort -f -u)

# Get the list of all maintainers
all_maintainers=$(echo "${maintainers_data}" | yq -r '.[].maintainers.[]')
all_maintainers=$(echo "${all_maintainers}" | sort -f -u)

# Write team member list files
global_admins=$(<${manifest_path}/global-admins.csv)
global_admins=$(echo "${global_admins}" | tail -n +2)
global_admins=(${global_admins})

write_team_member_list()
{
  output_file="$1"
  member_list="$2"

  echo "username,role" > "${output_file}"
  for user in ${member_list}; do
    if [[ " ${global_admins[@]} " =~ " ${user} " ]]; then
      echo "${user},maintainer" >> ${output_file}
    else
      echo "${user},member" >> "${output_file}"
    fi
  done
}

write_team_member_list "${manifest_path}/team/team-members/collaborators.csv" "${all_collaborators}"
write_team_member_list "${manifest_path}/team/team-members/maintainers.csv" "${all_maintainers}"
