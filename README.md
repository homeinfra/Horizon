# Horizon

This repository describes in a GitOps fashion the setup of my entire homelab
infrastructure including a kubernetes cluster named Horizon (in homage to the
[Event Horizon Telescope (EHT)](https://en.wikipedia.org/wiki/Event_Horizon_Telescope)).

## Prerequisites

The client environment is currently supported for the following:

### Windows 10 (or superior)

Open a command prompt window (CMD) and execute the following command:
<!-- markdownlint-disable MD013 -->
```bat
bitsadmin /transfer setup ^
https://raw.githubusercontent.com/jeremfg/setup/refs/heads/main/src/setup_wsldockergit.bat ^
%cd%\setup_wsldockergit.bat & setup_wsldockergit.bat -RepoUrl "git@github.com:homeinfra/Horizon.git" ^
-RepoRef "main" -EntryPoint "echo 'Welcome to Horizon!'"
```
<!-- markdownlint-enable MD013 -->
This will download and execute
[this script](https://raw.githubusercontent.com/jeremfg/setup/refs/heads/main/src/setup_wsldockergit.bat).
This script is designed to run on a fresh vanilla installation of Windows. At
the end of it's execution, it will have setup a Ubuntu environment
(running under WSL 2) where Docker is supported, the specified repository
cloned, and the entrypoint within called.

### Linux Ubuntu

[Download and execute this script](src/client/setup-linux). This script is
designed to run on a fresh vanilla installation of Linux Unbuntu, but might
work on any unbuntu-based distribution that supports apt-get. At the end of
it's execution, it will have setup an environment where docker is supported
and this respository was cloned.

You are now fully setup. Everything will run using bash and docker. Keep on
reading to figure out what to execute.

## Quick Start

Everything starts with the execution of [all.sh](all.sh) at the root. Calling
this will deploy the cluster, as currently configured.

## About this repo

Great care was taken in making sure this script will only perform edits to the
environmnent, reaching the described and desired outcome like you would expect
in a declarative philosophy. When it comes to persistent data, a retain policy
is used to make sure no data is ever lost. It is deemed a manual task and human
reponsibility to delete persistent data if desired and should not be automated.

### Goal

1. Deploy the entire infrastructure, including the Horizon cluster, starting
from the Xen/XCP-ng XAPI API and moving up the stack.
1. Maintain the entire Horizon cluster in a GitOps fashiopn.

### Non-goal

The code in this repository makes a few assumptions or has a few requirements:

1. Some steps are done manually, only described by text under /docs.
For example: Truenas configuration. Documentation is the entry point and single
source of truth.

### Remote controller environment

This was developed and is designed to run from within WSL2 Ubuntu 24.04 LTS
(Windows Subsystem for Linux), but we assume a native linux client would work as
well.

Developed using Microsoft VS Code

## Physical Nodes (actual hardware)

### QNAP (demers)

A modified QNAP TVS-663 running XCP-ng 8.2.1
See [homeinfra/demers-qnap](https://github.com/homeinfra/demers-qnap)

### SOL (demers)

A custom SFF server based on Supermicro's X10SDV-TLN4F motherboard
running XCP-ng 8.2.1
See [homeinfra/demers-sol](https://github.com/homeinfra/demers-sol)

### Network devices (demers)

Switches:

- Starlink: L2 managed, model S1100WP-8XGT-SE from Hassivo

Access Points:

- Goldstone: Ubiquiti UniFi U7-Pro

Wireless extenders:

- TDRS: Linksys WRT54G v5.0 running ddwrt in client bridge mode

Cable Modem:

- Unidentified: provided by ISP VMedia

### Kepler (sonia)

A custom desktop tower server based on Supermicro's X11SDV-8C-TP8F motherboard
See [homeinfra/sonia-kepler](https://github.com/homeinfra/sonia-kepler)

### Network devices (sonia)

Switches:

- Unidentified: Unmanaged, 1 GbE

Acces Points:

- Ubiquitu UniFi U6-Lite

Cable Modem:

- Unidentified: provided by ISP Oxio

## Virtual Nodes

### Anik (demers)

VM running on pool demers, running OPNSense, acting as primary router for demers

### NSSDC (demers)

VM running on pool demers, running Zentyal, acting as secondary domain controller
for Horizon

### Halley (demers)

VM running on host QNAP, running TrueNAS Scale and used as a NAS
See [homeinfra/demers-halley](https://github.com/homeinfra/demers-halley)

### Router (sonia)

VM running on pool sonia, running OPNSense, acting as primary router for sonia

### DC1 (sonia)

VM running on pool sonia, running OPNSense, acting as primary domain controller
for Horizon

### NAS (sonia)

VM running on host Kepler, running FreeNAS and used as a NAS

### Sagittarius ([Fedora CoreOS](https://fedoraproject.org/coreos/))

First controlplane node for my Horizon k8s cluster. Named in honor of
[Sagittarius A*](https://en.wikipedia.org/wiki/Sagittarius_A*) imaged for the
first time by EHT in 2022.

### Messier ([Fedora CoreOS](https://fedoraproject.org/coreos/))

Second controlpolane node for my Horizon k8s cluster. Named in honor of
[M87*](https://en.wikipedia.org/wiki/Messier_87#Supermassive_black_hole_M87*),
the first black hole ever imaged in 2019.

### Bouvard ([Fedora CoreOS](https://fedoraproject.org/coreos/))

First worker node for my Horizon k8s cluster. Named in honor of
[Alexis Bouvard](https://en.wikipedia.org/wiki/Alexis_Bouvard), french
astronomer who hypothesised the existence of Neptune based on irregularities he
found in Uranus' orbit.

### LeVerrier ([Fedora CoreOS](https://fedoraproject.org/coreos/))

Second worker node for my Horizon k8s cluster. Named in honor of
[Urbain Le Verrier](https://en.wikipedia.org/wiki/Urbain_Le_Verrier), french
astonomer and mathematician who predicted the position of Neptune based on
Alexis Bouvar's observations.

## TODOs

### Catch up to previous/existing work

1. Create Kosmos VM
1. Connect SOL and QNAP together in a pool
1. Complete startup/shutdown logic with UPS

### Next steps

1. Rework CoreOS install to Talos Linux instead
1. Attempt a transition to terraform. (When XOA Lite is supported).
1. Deploy k8s control nodes
1. Deploy k8s worker nodes
1. Deploy CNI calico
1. Configure geolocation configuration (multi-site storage constraints)
1. Deploy CSI smb
1. Deploy external ingress controller (Can publish DNS updates to Namecheap)
1. Deploy internal ingress controller (Can configure Unboud on OPNsense)
1. Deploy XOA
1. Deploy NetData appliance
1. Deploy syslog-ng
1. Automatic backup of critical infrastructure.
   We should be doing an automatic backup of
   OPNSense, TrueNAS, Zentyal (and switches?)
1. Deploy bluebook
1. Deploy Immich for Cellphone picture cloud backup
1. Deploy Jellyfin
1. Deploy Arrrr
1. Deploy Torrent
1. Deploy Home Assistant

### Quality of Life improvements

1. Cleanup all instances of "# Variables loaded externally",
   to be replaced by checks for -z.
1. Revisit all instances where we disable shellcheck warnings
1. Enhance slf4.sh to support stack traces on logFatal
1. Add a function to manually dump a stack trace in slf4.sh
1. Update GUARDS everywhere to print a warning and stack trace
1. Can we have a reusable utility function for the GUARDS?
1. Eliminate executables that are also used as library
1. Do the Unbuntu deployment script
1. Replace Halley configuration from manual GUI to Automated json
