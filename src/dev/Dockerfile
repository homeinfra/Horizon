# SPDX-License-Identifier: MIT
#
# Development environment

# hadolint ignore=DL3007
FROM horizon-prod-image:latest

ARG LOCAL_BINDIR="/usr/local"

ARG SYS_GROUP
ARG DEV_USER
ARG DEV_GROUP
ARG DEV_UID
ARG DEV_GID
ARG VER_VERSION

LABEL version=${VER_VERSION}

SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

USER root

# Add a non-root user 'dev' with sudo access which doesn't require password input.
# This user will be the default user used in the development environment.
RUN addgroup ${DEV_GROUP} -g ${DEV_GID} && \
  adduser ${DEV_USER} -u ${DEV_UID} -G ${DEV_GROUP} -h /home/${DEV_USER} -s /bin/ash -D && \
  adduser ${DEV_USER} wheel && \
  adduser ${DEV_USER} ${SYS_GROUP} && \
  echo "${DEV_USER}:${DEV_USER}" | chpasswd && \
  sed -i 's/^# %wheel ALL=(ALL:ALL) NOPASSWD: ALL$/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers

# The following packages are requirements for different pre-commit linters:
# - python3-dev
# - ruby-dev
# - build-base
# - nodejs (markdownlint)
# - npm (markdownlint)
# hadolint ignore=DL3018
RUN apk add --no-cache \
  pre-commit \
  shellcheck \
  python3-dev \
  build-base \
  ruby-dev \
  nodejs \
  npm \
  cargo \
  && cargo install --root ${LOCAL_BINDIR} \
  dotenv-linter \
  && apk del \
  cargo \
  && apk cache clean --purge

# # Copy the entrypoint script into the container
COPY dev_entry ${LOCAL_BINDIR}/bin/dev_entry
RUN chmod +x ${LOCAL_BINDIR}/bin/dev_entry

USER ${DEV_USER}
ENV PATH=/home/${DEV_USER}/.local/bin:${PATH}
ENV SOPS_AGE_KEY_FILE=/home/${DEV_USER}/src/.config/homeinfra.txt

# Install script dependencies
RUN curl -sLo- https://get.bpkg.sh | bash \
  && bpkg install -g jeremfg/slf4.sh \
  && bpkg install -g jeremfg/config.sh

ENTRYPOINT ["/usr/local/bin/dev_entry"]
