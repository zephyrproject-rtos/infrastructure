#!/usr/bin/env bash

# This script generates a collaborator list for every module repository listed
# as `West project` in the Zephyr MAINTAINERS.yml file.

set -e

usage()
{
  echo "Usage $(basename $0) maintainers_file manifest_path"
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

# Read global admin list
global_admins=$(<${manifest_path}/global-admins.csv)
global_admins=$(echo "${global_admins}" | tail -n +2)
global_admins=(${global_admins})

# Set skipped module list
skipped_modules=(
  bsim
  babblesim_base
  babblesim_ext_2G4_libPhyComv1
  babblesim_ext_2G4_phy_v1
  babblesim_ext_2G4_channel_NtNcable
  babblesim_ext_2G4_channel_multiatt
  babblesim_ext_2G4_modem_magic
  babblesim_ext_2G4_modem_BLE_simple
  babblesim_ext_2G4_device_burst_interferer
  babblesim_ext_2G4_device_WLAN_actmod
  babblesim_ext_2G4_device_playback
  babblesim_ext_libCryptov1
  )

# Get the maintainer data for modules (aka. west projects)
readarray module_maintainer_entries < <(echo "${maintainers_data}" |
  yq -r -o=j -I=0 'with_entries(select(.key == "West project: *")) | to_entries()[]')

for module_maintainer_entry in "${module_maintainer_entries[@]}"; do
  # Get entry data
  name=$(echo "${module_maintainer_entry}" |
    jq -r '.key | sub("West project: "; "")')
  maintainers=$(echo "${module_maintainer_entry}" |
    jq -r 'try .value.maintainers[]')
  collaborators=$(echo "${module_maintainer_entry}" |
    jq -r 'try .value.collaborators[]')

  # Check for skipped module
  if [[ " ${skipped_modules[@]} " =~ " ${name} " ]]; then
    echo "Skipped ${name}"
    continue
  fi

  # Write repositoy member list
  echo "Processing ${name}"
  collab_list_file="${manifest_path}/repository/repository-members/${name}.csv"

  ## Write CSV header
  echo "type,id,permission" > ${collab_list_file}

  ## Write team entries
  echo "team,maintainers,triage" >> ${collab_list_file}
  echo "team,release,push" >> ${collab_list_file}

  ## Write maintainer entries
  for maintainer in ${maintainers}; do
    if [[ " ${global_admins[@]} " =~ " ${maintainer} " ]]; then
      echo "user,${maintainer},admin" >> ${collab_list_file}
    else
      echo "user,${maintainer},maintain" >> ${collab_list_file}
    fi
  done

  ## Write collaborator entries
  for collaborator in ${collaborators}; do
    if [[ " ${global_admins[@]} " =~ " ${collaborator} " ]]; then
      echo "user,${collaborator},admin" >> ${collab_list_file}
    else
      echo "user,${collaborator},push" >> ${collab_list_file}
    fi
  done
done
