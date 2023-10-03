# hadolint ignore=DL3007
FROM horizon-prod-image:latest

ARG LOCAL_BINDIR="/usr/local"

ARG SYS_GROUP
ARG DEV_USER
ARG DEV_GROUP
ARG VER_VERSION

LABEL version=${VER_VERSION}

SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

# Add a non-root user 'dev' with sudo access which doesn't require password input.
# This user will be the default user used in the development environment.
RUN addgroup ${DEV_GROUP} -g 1000 && \
  adduser ${DEV_USER} -u 1000 -G ${DEV_GROUP} -h /home/${DEV_USER} -s /bin/ash -D && \
  adduser ${DEV_USER} wheel && \
  adduser ${DEV_USER} ${SYS_GROUP} && \
  echo "${DEV_USER}:${DEV_USER}" | chpasswd && \
  sed -i 's/^# %wheel ALL=(ALL:ALL) NOPASSWD: ALL$/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers

# Added "python3-dev", "ruby-dev" and "build-base" as prerequisites for multiple pre-commit hook installations
RUN apk add --no-cache \
  git=2.40.1-r0 \
  python3-dev=3.11.5-r0 \
  shellcheck=0.9.0-r1 \
  build-base=0.5-r3 \
  ruby-dev=3.2.2-r0 \
  cargo=1.71.1-r0 \
  && pip3 install --no-cache-dir \
  pre-commit==3.4.0 \
  && cargo install --root ${LOCAL_BINDIR} \
  dotenv-linter --version=3.3.0 \
  && apk del \
  cargo \
  && apk cache clean --purge
