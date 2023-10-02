FROM alpine:3.18.4

ARG VER_VERSION
LABEL version=${VER_VERSION}

SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

# Update the package repositories
RUN apk update && apk add --no-cache \
  sudo=1.9.13_p3-r2 \
  bash=5.2.15-r5 \
  curl=8.3.0-r0
