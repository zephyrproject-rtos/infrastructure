#!/usr/bin/env bash

# This script queries and print out the "canonical" username for a GitHub user.
#
# As example, for a user with the registered username `RandomUser1234`, this
# scripts returns `RandomUser1234` when `randomuser1234`, `rAndOMuSer1234` or
# any other case variation of the username is specified.

set -e

usage()
{
	echo "Usage: $(basename $0) username"
}

# Validate and parse arguments
if [ "$1" == "" ]; then
  usage
  echo
  echo "username must be specified."
  exit 1
fi

username=$1
cache_file=".username.cache"

# Attempt to retrieve the canonical username from a local cache file
if [ -f "${cache_file}" ]; then
  cache_data=($(<${cache_file}))

  for cache_entry in "${cache_data[@]}"; do
    if [[ "${cache_entry,,}" == "${username,,}" ]]; then
      # Found a matching cache entry; print it and exit
      echo "${cache_entry}"
      exit 0
    fi
  done
fi

# Retrieve user data from GitHub
user_data=$(gh api /users/${username})
canonical_username=$(echo "${user_data}" | jq -r '.login')

# Ensure that canonical username is alphanumerically identical to the specified
# username
if [[ "${canonical_username,,}" != "${username,,}" ]]; then
  echo "Invalid user data."
  exit 2
fi

# Save canonical username to the cache file
echo "${canonical_username}" >> ${cache_file}

# Print canonical username
echo "${canonical_username}"
