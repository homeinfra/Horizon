# hadolint ignore=DL3007
FROM horizon-prod-base-image:latest

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

# Added "python3-dev" as prerequisites for SOPS
# Added "openssl-dev" and "zstd-dev" as prerequisites for coreos-installer
RUN apk add --no-cache \
  python3=3.11.5-r0 \
  py3-pip=23.1.2-r0 \
  python3-dev=3.11.5-r0 \
  samba-client=4.18.5-r0 \
  cargo=1.71.1-r0 \
  openssl-dev=3.1.3-r0 \
  zstd-dev=1.5.5-r4 \
  && pip3 install --no-cache-dir \
  virtualenv==20.24.5 \
  python-dotenv==1.0.0 \
  sops==1.18 \
  age==0.5.1 \
  && cargo install \
  coreos-installer --version=0.18.0 \
  && apk del \
  openssl-dev \
  zstd-dev \
  cargo \
  && apk cache clean --purge

# This is where coreos-installer ends up
ENV PATH="${PATH}:/root/.cargo/bin"

# Install butane
RUN curl -Lo /usr/local/bin/butane ${BUTANE_URL} && \
  chmod +x /usr/local/bin/butane

# From docker-compose.yml
EXPOSE ${IG_PORT}

# Set the command to run when the container starts
CMD ["/bin/sh"]
