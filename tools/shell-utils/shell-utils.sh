#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# Just some utility functions

# Executes command $1, capture the output in $RES and return the original exit code
# @param[in] $1: String containing the command to execute
# return: $? returned by the coomand
execute() {
    local ret=0
    local tmp=$(tempfile)
    eval "$1" > $tmp
    ret=$?
    RES=$(cat $tmp)
    RES=${RES%$'\r'}
    rm -f $tmp
    return $ret
}

# https://askubuntu.com/a/1463894
# Adds an environment variable to bashrc
# @param[in] $1: Name of the env variable
# @param[in] $2: Value of the env variable
# return: 0 if successful, 1 otherwise
add_env() {
    if [[ -z "$1" ]] || [[ -z "$2" ]]; then
        return 1
    fi

    local rcFile="$HOME/.bashrc"
    local prop="$1"   # export property to insert
    local val="$2"    # the desired value

    if grep -q "^export $prop=" "$rcFile"; then
        sed -i "s,^export $prop=.*$,export $prop=$val," "$rcFile"
        echo "[updated] export $prop=$val"
    else
        echo -e "export $prop=$val" >> "$rcFile"
        echo "[inserted] export $prop=$val"
    fi

    source $rcFile

    return 0
}

# https://askubuntu.com/a/1463894
# Adds an environment variable to bashrc
# @param[in] $1: Name of the env variable to delete
# return: 0 if successful, 1 otherwise
remove_env() {
    if [[ -z "$1" ]]; then
        return 1
    fi

    local rcFile="~/.bashrc"
    local prop="POSTGRE_PORT"    # export property to delete

    if grep -q "^export $prop=" "$rcFile"; then
        sed -i "/^export $prop=.*$/d" "$rcFile"
        echo "[deleted] export $prop"

        unset $prop

        return 0
    else
        echo "[not found] export $prop"
        return 1
    fi
}

