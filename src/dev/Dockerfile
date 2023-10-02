FROM horizon-prod-image

ARG SYS_GROUP
ARG DEV_USER
ARG DEV_GROUP

# Add a non-root user 'dev' with sudo access which doesn't require password input.
# This user will be the default user used in the development environment.
RUN addgroup ${DEV_GROUP} -g 1000 && \
  adduser ${DEV_USER} -u 1000 -G ${DEV_GROUP} -h /home/${DEV_USER} -s /bin/ash -D && \
  adduser ${DEV_USER} wheel && \
  adduser ${DEV_USER} ${SYS_GROUP} && \
  echo "${DEV_USER}:${DEV_USER}" | chpasswd && \
  sed -i 's/^# %wheel ALL=(ALL:ALL) NOPASSWD: ALL$/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers

RUN apk add --no-cache \
  git \
  && pip3 install \
  pre-commit
