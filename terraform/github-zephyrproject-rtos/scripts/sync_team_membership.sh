#!/usr/bin/env bash

# This scripts generates the 'collaborators' and 'maintainers' GitHub team
# member list files from the Zephyr MAINTAINERS.yml file.

set -e

get_canonical_username="$(dirname "${BASH_SOURCE[0]}")/get_canonical_username.sh"

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

# Read global admin list
global_admins=$(<${manifest_path}/global-admins.csv)
global_admins=$(echo "${global_admins}" | tail -n +2)
global_admins=(${global_admins})

# Write maintainer and collaborator team member list files
collaborators_csv="${manifest_path}/team/team-members/collaborators.csv"
maintainers_csv="${manifest_path}/team/team-members/maintainers.csv"

write_team_member_list()
{
  output_file="$1"
  member_list="$2"

  echo "username,role" > "${output_file}"
  for username in ${member_list}; do
    canonical_username=$(${get_canonical_username} ${username})

    if [[ " ${global_admins[@]} " =~ " ${canonical_username} " ]]; then
      echo "${canonical_username},maintainer" >> ${output_file}
    else
      echo "${canonical_username},member" >> "${output_file}"
    fi
  done
}

write_team_member_list "${collaborators_csv}" "${all_collaborators}"
write_team_member_list "${maintainers_csv}" "${all_maintainers}"

# Add all maintainers and collaborators to the contributors team member list
contributors_csv="${manifest_path}/team/team-members/contributors.csv"

tail -n +2 "${maintainers_csv}" >> "${contributors_csv}"
tail -n +2 "${collaborators_csv}" >> "${contributors_csv}"

contributors_data=$(tail -n +2 "${contributors_csv}")
contributors_data=$(echo "${contributors_data}" | sort -f | uniq -i)

echo "username,role" > "${contributors_csv}"
echo "${contributors_data}" >> "${contributors_csv}"
