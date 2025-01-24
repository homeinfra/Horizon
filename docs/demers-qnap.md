# demers-qnap

## Installation instructions

Many of the steps below can probably be skipped if they were already done
in the past. The third section is where it starts to get interesting.

### First, bring-up the server

1. Install OS manually from a USB stick, making sure of the following:
    1. The management interface is configured on interface 00:08:9b:ef:8d:72
        (eth0)
    1. That interface is configured with static IP ${XEN_MGT}
1. Execute the boostrapping locally or remotely via SSH
   (See repo homeinfra/demers-qnap)

### Secondly, configure your management client environment

1. Make sure you can ping ${XEN_MGT}
1. If on Windows, configure your environment
    1. See README.md's section on Windows 10
1. If on Linux, configure your environment
    1. See README.md's section on Linux Ubuntu
1. Once in your host environment, pepare the docker image
    1. `./src/host/container build`
1. Configure your docker environment
    1. `./src/host/container exec -- ./src/client/setup-docker`
    1. Follow the on-screen instructions (if any)

### Thirdly, configure demers-qnap

1. Configure the demers-qnap server
    1. `./src/host/container exec -- ./src/bootstrap/00-baremetal/demers-qnap/setup`

## TODOs
