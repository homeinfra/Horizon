# shellcheck shell=bash
# SPDX-License-Identifier: MIT
#
# Web crawling utilities

# Prevent sourcing this script
if [[ -z ${GUARD_ISO_SH} ]]; then
  GUARD_ISO_SH=1
else
  logWarn "Re-sourcing iso.sh"
  return 0
fi

# Install into the ISO SR from a URL
#
# Parameters:
#   $1[out]: The ISO name to use
#   $2[in] : The URL to download the ISO from
# Returns:
#   0: If the ISO was successfully installed
#   1: If an error occurred
iso_populate_web() {
  local __result_iso_name="${1}"
  local __url="${2}"

  if [[ -z "${__url}" ]]; then
    logError "URL not specified"
    return 1
  fi

  local res iso_name iso_file

  # Check if ISO is already available
  iso_name=$(basename "${__url}")
  xe_iso_uuid_by_name res "${iso_name}"
  res=$?
  if [[ "${res}" -eq 1 ]]; then
    return 1
  elif [[ "${res}" -eq 2 ]]; then
    logInfo "ISO not present in SR"
  else
    logInfo "No need to download, already on ISO SR"
    eval "${__result_iso_name}=${iso_name}"
    return 0
  fi

  # If we here, we need to install it
  if [[ -z "${DIR_DOWNLOAD}" ]]; then
    logError "DIR_DOWNLOAD is not set"
    return 1
  elif ! web_download iso_file "${__url}" "${DIR_DOWNLOAD}"; then
    logError "Failed to download TrueNAS ISO"
    return 1
  elif ! nu_file_upload "${iso_file}" "${XEN_ISO_LIB}" "${XEN_ISO_USER}" "${XEN_ISO_PWD}"; then
    logError "Failed to upload TrueNAS ISO"
    return 1
  elif ! xe_stor_refresh "${ISO_STOR_NAME}"; then
    logError "Failed to refresh ISO SR"
    return 1
  fi

  eval "${__result_iso_name}='${iso_name}'"

  return 0
}

# Variables loaded externally
if [[ -z "${ISO_STOR_NAME}" ]]; then ISO_STOR_NAME=""; fi
if [[ -z "${XEN_ISO_LIB}" ]]; then XEN_ISO_LIB=""; fi
if [[ -z "${XEN_ISO_USER}" ]]; then XEN_ISO_USER=""; fi
if [[ -z "${XEN_ISO_PWD}" ]]; then XEN_ISO_PWD=""; fi
if [[ -z "${DIR_SETUP}" ]]; then DIR_SETUP=""; fi
if [[ -z "${DIR_XAPI}" ]]; then DIR_XAPI=""; fi

###########################
###### Startup logic ######
###########################

# Get directory of this script
# https://stackoverflow.com/a/246128
ISO_SOURCE=${BASH_SOURCE[0]}
while [[ -L "${ISO_SOURCE}" ]]; do # resolve $ISO_SOURCE until the file is no longer a symlink
  ISO_ROOT=$(cd -P "$(dirname "${ISO_SOURCE}")" >/dev/null 2>&1 && pwd)
  ISO_SOURCE=$(readlink "${ISO_SOURCE}")
  [[ ${ISO_SOURCE} != /* ]] && ISO_SOURCE=${ISO_ROOT}/${ISO_SOURCE} # if $ISO_SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
ISO_ROOT=$(cd -P "$(dirname "${ISO_SOURCE}")" >/dev/null 2>&1 && pwd)
ISO_ROOT=$(realpath "${ISO_ROOT}/../..")

# Determine BPKG's global prefix
if [[ -z "${PREFIX}" ]]; then
  if [[ $(id -u || true) -eq 0 ]]; then
    PREFIX="/usr/local"
  else
    PREFIX="${HOME}/.local"
  fi
fi

# Import dependencies
# shellcheck disable=SC1091
if ! source "${PREFIX}/lib/slf4.sh"; then
  echo "Failed to import slf4.sh"
  exit 1
fi

# shellcheck disable=SC1091
if ! source "${DIR_SETUP}/src/web.sh"; then
  logError "Failed to load web.sh"
  return 1
fi
# shellcheck disable=SC1091
if ! source "${DIR_XAPI}/src/xe_storage.sh"; then
  logError "Failed to load xe_storage.sh"
  return 1
fi

if [[ -p /dev/stdin ]] && [[ -z ${BASH_SOURCE[0]} ]]; then
  # This script was piped
  logFatal "This script cannot be piped"
elif [[ ${BASH_SOURCE[0]} != "${0}" ]]; then
  # This script was sourced
  :
else
  # This script was executed
  logFatal "This script cannot be executed"
fi
