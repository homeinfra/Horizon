FROM horizon-prod-image:${VER_VERSION}

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

RUN apk add --no-cache \
  git=2.40.1-r0 \
  shellcheck=0.9.0-r1 \
  && pip3 install --no-cache-dir \
  pre-commit==3.4.0
