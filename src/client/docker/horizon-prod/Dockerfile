FROM horizon-prod-base-image

ARG SYS_GROUP
ARG SYS_USER
ARG BUTANE_URL

# Add user and group for executed processes in prod
RUN addgroup ${SYS_GROUP} --system && \
  adduser ${SYS_USER} --system -u 10001 -G ${SYS_GROUP}
# Previously the adduser had these extra options: --create-home -d /home/${SYS_USER} -s /bin/ash

# Added "python3-dev" to help install SOPS
# Added "openssl-dev" and "zstd-dev" for coreos-installer
RUN apk add --no-cache \
  python3 \
  py3-pip \
  python3-dev \
  samba-client \
  cargo \
  openssl-dev \
  zstd-dev \
  && pip3 install \
  virtualenv \
  python-dotenv \
  sops \
  age \
  && cargo install \
  coreos-installer

# This is where coreos-installer ends up
ENV PATH="${PATH}:/root/.cargo/bin"

# Install butane
RUN curl -Lo /usr/local/bin/butane ${BUTANE_URL} && \
  chmod +x /usr/local/bin/butane

# From docker-compose.yml
EXPOSE ${IG_PORT}

# Set the command to run when the container starts
CMD ["/bin/sh"]