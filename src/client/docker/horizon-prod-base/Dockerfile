# SPDX-License-Identifier: MIT
#
# Base image for Horizon management

# hadolint ignore=DL3007
FROM alpine:latest

ARG VER_VERSION
LABEL version=${VER_VERSION}

SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

# hadolint ignore=DL3018
RUN apk update && apk add --no-cache \
  sudo \
  bash \
  curl
