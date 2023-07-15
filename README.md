# Horizon
This repository describes in a GitOps fashion the setup of my kuberetes cluster named Horizon (in homage to the [Event Horizon Telescope (EHT)](https://en.wikipedia.org/wiki/Event_Horizon_Telescope)).

## About this repo

Everything starts with the execution of [all.sh](all.sh) at the root.
Great care was taken in making sure this script will only perform edits to the environmnent, reaching the described and desired outcome like you would expect in a declarative philosophy.
When it comes to persistent data, a retain policy is used to make sure no data is ever lost. It is deemed a manual task and human reponsibility to delete persistent data if desired and should not be automated.

### Goal
1. Deploy the entire Horizon cluster, starting from the Xen/XCP-ng XAPI API and moving up the stack.

2. Maintain the entire Horizon cluster in a GitOps fashiopn.
### Non-goal
The code in this repository makes a few assumptions or has a few requirements:

1. It is assumed that the base networking infrastructure (LAN, AD, DHCP and DNS) is alreadu avaiable, deployed and running. This is accomplised by [SOL] and [Kepler].

2. It is assumed that at least one XCP-ng hypervisor is already installed, configured and running, ready to host new VMs deployed on it and maintained by this repo.

### Remote controller environment
This was developed and is designed to run from within WSL2 Ubuntu 20.04 (Windows Subsystem for Linux). This is currently NOT compatible with native linux but it is believed the changes required would be pretty minimal.

Developed using Microsoft VS Code

## Nodes
###  Sagittarius ([Fedora CoreOS](https://fedoraproject.org/coreos/))
First controlplane node for my Horizon k8s cluster. Named in honor of [Sagittarius A*](https://en.wikipedia.org/wiki/Sagittarius_A*) imaged for the first time by EHT in 2022.

### Messier ([Fedora CoreOS](https://fedoraproject.org/coreos/))
Second controlpolane node for my Horizon k8s cluster. Named in honor of [M87*](), the first black hole ever imaged in 2019.

### Bouvard ([Fedora CoreOS](https://fedoraproject.org/coreos/))
First worker node for my Horizon k8s cluster. Named in honor of [Alexis Bouvard](https://en.wikipedia.org/wiki/Alexis_Bouvard), french astronomer who hypothesised the existence of Neptune based on irregularities he found in Uranus' orbit.

### LeVerrier ([Fedora CoreOS](https://fedoraproject.org/coreos/))
Second worker node for my Horizon k8s cluster. Named in honor of [Urbain Le Verrier](https://en.wikipedia.org/wiki/Urbain_Le_Verrier), french astonomer and mathematician who predicted the position of Neptune based on Alexis Bouvar's observations.

## TODOs
	- [ ] Everything
