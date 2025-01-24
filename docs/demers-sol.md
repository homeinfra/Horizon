# demers-sol

## Installation instructions

Many of the steps below can probably ne skipped if they were already done
in the past. The third section is where it starts to get inetersting.

### First, bring-up the server

1. Install OS manually from virtually mounting the ISO via IPMI, using:
    1. The management interface is configured on interface 00:25:90:b9:25:ce
       (eth0)
    1. That interface is configured with static IP ${XEN_MGT}
1. Execute the bootstrapping locally or remotely via SSH
   (See repo homeinfra/demers-sol)

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

### Thirdly, configure demers-sol

1. Configure the demers-sol server
    1. `./src/host/container exec -- ./src/bootstrap/00-baremetal/demers-sol/setup`

## TODOs

- Create demers-sol repo and installation setup for section 1 above
- Create setup script for configuring the demers-sol installation
