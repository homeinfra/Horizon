#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# 
# Source this into any shell script you wish to add logging support.
# Inspired From: https://serverfault.com/a/103569

LEVEL_ALL=0    # Enable all possible logs.
LEVEL_TEST=1   # Only used by developers to temporarily add logs that should never get commited.
LEVEL_TRACE=2  # Low level tracing of very detailed specifc information.
LEVEL_DEBUG=3  # Might allow to investigate and resolve a bug.
LEVEL_INFO=4   # Default level. High level indications of the paths the code took.
LEVEL_WARN=5   # Unusual behavior that don't cause an issue to the current execution.
LEVEL_ERROR=6  # A recoverable error occured. The program is still executing properly but the user is not getting the desired outcome.
LEVEL_FATAL=7  # Unrecoverable error. Program is exiting immediately for safety as it wasn't designed to continue after this.
LEVEL_OFF=8    # Turns of all logs

# If no level is configured, start at INFO
if [ -z $LOG_LEVEL ]; then
  LOG_LEVEL=$LEVEL_INFO
fi

# By default do not print logs on the console but only in the log file
if [ -z $LOG_CONSOLE ]; then
  LOG_CONSOLE=0
fi
# Set the log level
#
# @parms[in] #1: The logging level to be used from now on, using one of the LEVEL_* values
logSetLevel() {
    LOG_LEVEL=$1
}

logFatal() {
    if [ "$LOG_LEVEL" -le $LEVEL_FATAL ]; then
        log "FATAL " "$1"
    fi
    exit 1
}

logError() {
    if [ "$LOG_LEVEL" -le $LEVEL_ERROR ]; then
        log "ERROR " "$1"
    fi
}

logWarn() {
    if [ "$LOG_LEVEL" -le $LEVEL_WARN ]; then
        log "WARN  " "$1"
    fi
}

logInfo() {
    if [ "$LOG_LEVEL" -le $LEVEL_INFO ]; then
        log "INFO  " "$1"
    fi
}

logDebug() {
    if [ "$LOG_LEVEL" -le $LEVEL_DEBUG ]; then
        log "DEBUG " "$1"
    fi
}

logTrace() {
    if [ "$LOG_LEVEL" -le $LEVEL_TRACE ]; then
        log "TRACE " "$1"
    fi
}

logTest() {
    if [ "$LOG_LEVEL" -le $LEVEL_TEST ]; then
        log "TEST  " "$1"
    fi
}

log() {
    CUR="$(date +%F) $(date +%H:%M:%S)"
    if [ "$LOG_CONSOLE" == 1 ]; then
        echo "$CUR $1$2"
    else
        echo "$CUR $1$2" >> "$LOGFILE"
    fi
}

START="$(date +%F)_$(date +%H%M%S)"
ME="$(basename $0)"

# Path Configuration
ROOT="$(git rev-parse --show-toplevel)"
LOGFILE="$ROOT/.log/${ME%.*}_${START}.log"

# Setup logging
mkdir -p $ROOT/.log # Create log directory
exec 3>&1 4>&2 # Backup old descriptors
trap 'exec 2>&4 1>&3' 0 1 2 3 # Restore in case of signals
exec &> >(tee -a "$LOGFILE") # Redirect output
