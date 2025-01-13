# SPDX-License-Identifier: MIT
#
# Horizon management image

# hadolint ignore=DL3007
FROM horizon-prod-base-image:latest

ARG LOCAL_BINDIR="/usr/local"

ARG SYS_GROUP
ARG SYS_USER
ARG BUTANE_URL
ARG VER_VERSION

LABEL version=${VER_VERSION}

SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

# Add user and group for executed processes in prod
RUN addgroup ${SYS_GROUP} --system && \
  adduser ${SYS_USER} --system -u 10001 -G ${SYS_GROUP}
# Previously the adduser had these extra options: --create-home -d /home/${SYS_USER} -s /bin/ash

# Added "cargo", "openssl-dev" and "zstd-dev" as prerequisites for coreos-installer
# hadolint ignore=DL3018
RUN apk add --no-cache \
  python3 \
  samba-client \
  sops \
  age \
  git \
  cargo \
  openssl-dev \
  zstd-dev \
  && cargo install --root ${LOCAL_BINDIR} \
  coreos-installer \
  && apk del \
  openssl-dev \
  zstd-dev \
  cargo \
  && apk cache clean --purge

# Install butane
RUN curl -Lo ${LOCAL_BINDIR}/bin/butane ${BUTANE_URL} && \
  chmod +x ${LOCAL_BINDIR}/bin/butane

USER ${SYS_USER}
ENV PATH=/home/${SYS_USER}/.local/bin:${PATH}
ENV SOPS_AGE_KEY_FILE=/home/${SYS_USER}/src/.config/homeinfra.txt

# Install script dependencies
RUN curl -sLo- https://get.bpkg.sh | bash \
  && bpkg install -g jeremfg/slf4.sh \
  && bpkg install -g jeremfg/config.sh

# From docker-compose.yml
EXPOSE ${IG_PORT}

# Set the command to run when the container starts
CMD ["/bin/sh"]
