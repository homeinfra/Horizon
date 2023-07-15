#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# This scripts is a shortcut to run everything.
# Thus, also document the different general steps.
# This is the main entry point

export LOCAL_CONFIG=".config/demers.config:.config/local.config"

# Configre local environment
./src/client/setup-local.sh

# Deploy Horizon
./src/bootstrap/01-vm/horizon.sh
