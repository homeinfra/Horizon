#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# SLF4SH: Simple Logging Facade for Shell
#
# Add simple logging to any shell script. Logs are written to file in real-time, so you need to be aware of this
# if performance is a concern.
# Features:
#   1. Logs can optionally be displayed on stdout (disabled by default).
#      Console logs will also follow the currently configured log level
#   2. Log file used as output can be changed at any time, so you could theoretically implement your own
#      rolling file appender
#   3. stdout and stderr are also intercepted and captured, written to file along with the logs, creating a very useful
#      diagnostic tool showing everything displayed to the user inter-mixed with the logs.
#   4. Log level can be changed at any time during runtime
#   5. Very simple, one file library to be sourced. Just look at the code!
#
# Usage:
# 1. Source this file into any script you wish to add logging support
# 2. Start logging!
#
# Inspired From: https://serverfault.com/a/103569

# shellcheck disable=2034

## PUBLIC API ##

LEVEL_ALL=0   # Enable all possible logs.
LEVEL_TEST=1  # Only used by developers to temporarily add logs that should never get commited.
LEVEL_TRACE=2 # Low level tracing of very detailed specifc information.
LEVEL_DEBUG=3 # Might allow to investigate and resolve a bug.
LEVEL_INFO=4  # Default level. High level indications of the paths the code took.
LEVEL_WARN=5  # Unusual behavior that don't cause an issue to the current execution.
LEVEL_ERROR=6 # A recoverable error occured. The program is still executing properly but the user is not getting the desired outcome.
LEVEL_FATAL=7 # Unrecoverable error. Program is exiting immediately for safety as it wasn't designed to continue after this.
LEVEL_OFF=8   # Turns of all logs

# Set the log level. Default at startup: LEVEL_INFO
#
# @parms[in] $1: The logging level to be used from now on, using one of the LEVEL_* definitions
logSetLevel() {
  LOG_LEVEL="$1"
}

# Set the log file. Default at startup: <root of your project>/.log/<your script name>_date_time.log
#
# @params[in] $1: File to output the logs to
logSetFile() {
  LOGFILE="$1"
}

# Enable logs to be displayed on console. Default at startup: Disabled
logEnableConsole() {
  LOG_CONSOLE=1
}

# Disable logs from being displayed on the console (Default)
logDisableConsole() {
  LOG_CONSOLE=0
}

# Checks if LEVEL_* is currently enabled/being logged
#
# @params[in] $1: One of the LEVEL_* values to be tested
#
# @retval 1: LEVEL_* ($1) is being logged currently
#         0: LEVEL_* ($1) is NOT being logged currently
logIsLevelEnabled() {
  if [[ "$1" -lt "${LOG_LEVEL}" ]]; then
    return 0
  fi
  return 1
}

# Log a fatal event. Program will exit immediately with return code: 1
#
# @params[in] $1: Message to be logged
logFatal() {
  if [[ "${LOG_LEVEL}" -le ${LEVEL_FATAL} ]]; then
    log "FATAL " "$1"
  fi
  exit 1
}

# Log an error event.
#
# @params[in] $1: Message to be logged
logError() {
  if [[ "${LOG_LEVEL}" -le ${LEVEL_ERROR} ]]; then
    log "ERROR " "$1"
  fi
}

# Log a warning event.
#
# @params[in] $1: Message to be logged
logWarn() {
  if [[ "${LOG_LEVEL}" -le ${LEVEL_WARN} ]]; then
    log "WARN  " "$1"
  fi
}

# Log an info event.
#
# @params[in] $1: Message to be logged
logInfo() {
  if [[ "${LOG_LEVEL}" -le ${LEVEL_INFO} ]]; then
    log "INFO  " "$1"
  fi
}

# Log a debug event.
#
# @params[in] $1: Message to be logged
logDebug() {
  if [[ "${LOG_LEVEL}" -le ${LEVEL_DEBUG} ]]; then
    log "DEBUG " "$1"
  fi
}

# Log a trace event.
#
# @params[in] $1: Message to be logged
logTrace() {
  if [[ "${LOG_LEVEL}" -le ${LEVEL_TRACE} ]]; then
    log "TRACE " "$1"
  fi
}

# Log a test event.
#
# @params[in] $1: Message to be logged
logTest() {
  if [[ "${LOG_LEVEL}" -le ${LEVEL_TEST} ]]; then
    log "TEST  " "$1"
  fi
}

## PRIVATE API ##

log() {
  local date=0
  local time=0
  local full=0
  date=$(date +%F)
  time=$(date +%H:%M:%S)
  if [[ -z "$2" ]]; then
    $2 = $1
    $1 = "      "
  fi
  full="${date} ${time}"
  # Misleading on first sight. Remember that anything sent to stdout is also captured to file.
  # The 'else' condition is to avoid writing twice to file
  if [[ "${LOG_CONSOLE}" == 1 ]]; then
    echo -e "${full} [$1] $2"
  else
    echo -e "${full} [$1] $2" >>"${LOGFILE}"
  fi
}

START_DATE=$(date +%F)
START_TIME=$(date +%H%M%S)
START="${START_DATE}_${START_TIME}"
ME="$(basename "$0")"

# Configure default log file
ROOT="$(git rev-parse --show-toplevel)"      # Get root of this project (git depedency)
mkdir -p "${ROOT}/.log"                      # Create log directory
LOGFILE="${ROOT}/.log/${ME%.*}_${START}.log" # Define default log file

# Setup logging

exec 3>&1 4>&2                # Backup old descriptors
trap 'exec 2>&4 1>&3' 0 1 2 3 # Restore in case of signals
# shellcheck disable=2312
exec &> >(tee -a "${LOGFILE}") # Redirect output

# Apply default configuration

# If no level is configured, start at INFO
if [[ -z "${LOG_LEVEL}" ]]; then
  LOG_LEVEL=${LEVEL_INFO}
fi

# By default do not print logs on the console but only in the log file
if [[ -z "${LOG_CONSOLE}" ]]; then
  LOG_CONSOLE=0
fi
