#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# Just some utility functions

# https://askubuntu.com/a/1463894
# Adds an environment variable to bashrc
#
# @param[in] $1: Name of the env variable
# @param[in] $2: Value of the env variable
#
# return: 0 if successful, 1 otherwise
add_env() {
  if [[ -z "$1" ]] || [[ -z "$2" ]]; then
    echo "Expected 2 non-empty arguments"
    return 1
  fi

  local rcFile="${HOME}/.bashrc"
  local prop="$1"   # export property to insert
  local val="$2"    # the desired value

  if grep -q "^export ${prop}=" "${rcFile}"; then
    sed -i "s,^export ${prop}=.*$,export ${prop}=${val}," "${rcFile}"
    echo "[updated] export ${prop}=${val}"
  else
    echo -e "export ${prop}=${val}" >> "${rcFile}"
    echo "[inserted] export ${prop}=${val}"
  fi

  # shellcheck source=../../.bashrc
  source "${rcFile}"

  return 0
}

# https://askubuntu.com/a/1463894
# Adds an environment variable to bashrc
#
# @param[in] $1: Name of the env variable to delete
#
# return: 0 if successful, 1 otherwise
remove_env() {
  if [[ -z "$1" ]]; then
    echo "Expected 1 non-empty arguments"
    return 1
  fi

  local rcFile=~/.bashrc
  local prop="POSTGRE_PORT"    # export property to delete

  if grep -q "^export ${prop}=" "${rcFile}"; then
    sed -i "/^export ${prop}=.*$/d" "${rcFile}"
    echo "[deleted] export ${prop}"

    unset "${prop}"

    return 0
  else
    echo "[not found] export ${prop}"
    return 1
  fi
}
