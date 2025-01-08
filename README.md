# Horizon

This repository describes in a GitOps fashion the setup of my kubernetes cluster named Horizon (in homage to the
[Event Horizon Telescope (EHT)](https://en.wikipedia.org/wiki/Event_Horizon_Telescope)).

## Prerequisites

The client environment is currently supported for the following:

### Windows 10 (or superior)

Open a command prompt window (CMD) and execute the following command:

```bat
bitsadmin /transfer setup ^
https://raw.githubusercontent.com/jeremfg/setup/refs/heads/main/src/setup_wsldockergit.bat ^
%cd%\setup_wsldockergit.bat & setup_wsldockergit.bat -RepoUrl "https://github.com/homeinfra/Horizon.git" ^
-RepoRef "feature/docker" -EntryPoint "echo 'Welcome to Horizon!'"
```

This will download and execute [this script](https://raw.githubusercontent.com/jeremfg/setup/refs/heads/main/src/setup_wsldockergit.bat). This script is designed to run on a fresh
vanilla installation of Windows. At the end of it's execution, it will have setup a Ubuntu environment
(running under WSL 2) where Docker is supported, the specified repository cloned, and the entrypoint within called.

### Linux Ubuntu

[Download and execute this script](src/client/setup-linux). This script is designed to run on a fresh vanilla
installation of Linux Unbuntu, but might work on any unbuntu-based distribution that supports apt-get. At the end of
it's execution, it will have setup an environment where docker is supported and this respository was cloned.

You are now fully setup. Everything will run using bash and docker. Keep on reading to figure out what to execute.

## Quick Start

Everything starts with the execution of [all.sh](all.sh) at the root. Calling this will deploy the cluster, as currently
configured.

## About this repo

Great care was taken in making sure this script will only perform edits to the environmnent, reaching the described and
desired outcome like you would expect in a declarative philosophy.
When it comes to persistent data, a retain policy is used to make sure no data is ever lost. It is deemed a manual task
and human reponsibility to delete persistent data if desired and should not be automated.

### Goal

1. Deploy the entire Horizon cluster, starting from the Xen/XCP-ng XAPI API and moving up the stack.
1. Maintain the entire Horizon cluster in a GitOps fashiopn.

### Non-goal

The code in this repository makes a few assumptions or has a few requirements:

1. It is assumed that the base networking infrastructure (LAN, AD, DHCP and DNS) is alreadu avaiable, deployed and
running. This is accomplised by [SOL] and [Kepler].
1. It is assumed that at least one XCP-ng hypervisor is already installed, configured and running, ready to host new VMs
deployed on it and maintained by this repo.

### Remote controller environment

This was developed and is designed to run from within WSL2 Ubuntu 20.04 (Windows Subsystem for Linux). This is currently
NOT compatible with native linux but it is believed the changes required would be pretty minimal.

Developed using Microsoft VS Code

## Nodes

### Sagittarius ([Fedora CoreOS](https://fedoraproject.org/coreos/))

First controlplane node for my Horizon k8s cluster. Named in honor of
[Sagittarius A*](https://en.wikipedia.org/wiki/Sagittarius_A*) imaged for the first time by EHT in 2022.

### Messier ([Fedora CoreOS](https://fedoraproject.org/coreos/))

Second controlpolane node for my Horizon k8s cluster. Named in honor of
[M87*](https://en.wikipedia.org/wiki/Messier_87#Supermassive_black_hole_M87*), the first black hole ever imaged in
2019.

### Bouvard ([Fedora CoreOS](https://fedoraproject.org/coreos/))

First worker node for my Horizon k8s cluster. Named in honor of
[Alexis Bouvard](https://en.wikipedia.org/wiki/Alexis_Bouvard), french astronomer who hypothesised the existence of
Neptune based on irregularities he found in Uranus' orbit.

### LeVerrier ([Fedora CoreOS](https://fedoraproject.org/coreos/))

Second worker node for my Horizon k8s cluster. Named in honor of
[Urbain Le Verrier](https://en.wikipedia.org/wiki/Urbain_Le_Verrier), french astonomer and mathematician who predicted
the position of Neptune based on Alexis Bouvar's observations.

## TODOs

TODO For the current docker branch

1. ~~Complete and finalize testing of the Windows deployment script.~~
1. ~~Do the Unbuntu deployment script.~~
1. Installed the right version of SOPS in the container (currently have the old version 1 in python).
1. Configure the dotenv-linter. Make it happy with the current .config/ files.
1. Install pre-commit the right way and look at the missing/proposed formatter that aren't already there.
1. Install xe-cli into the docker image.
1. Make sure we are at the same stage as this spring.

TODO For mid term

1. Rename logger.sh into slf4sh.sh.
1. Extract it and semver into libraries to be published on my github account. Look into shell package managers.
1. Extract the environment setup scripts into their own modules so they can be shared.
1. Rework lib xapi-shell to remove MS Windows quirks. Streamline with new strategy of "out" function parameters. Or
maybe replace with python3?

TODO For long term (Finally caught up? Proceed with next steps...)

1. Get SSH key automatic generation working.
1. Attempt a transition to terraform.
1. Attempt a switch from FCOS to Talos. Apparently it even has terraform support.
1. Deploy 2 k8s control nodes
1. Deploy 2 k8s worker nodes
1. Deploy CNI calico
1. Configure geolocation configuration (multi-site storage constraints)
1. Deploy CSI smb
1. Deploy bluebook
1. Deploy XOA
1. Deploy Unify controller
1. Deploy external ingress controller (Can publish DNS updates to Namecheap)
1. Deploy internal ingress controller (Can configure Unboud on OPNsense)
1. Look for a centralized logging solution (SYSLOG server? - try to have better than emails)
1. Deploy Owncould (or similar - backup pictures on cellphones automatically)
1. Deploy Jellyfin
1. Deploy Arrrr
1. Deploy Home Assistant
