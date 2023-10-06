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
TODO For the current docker branch
1. Installed the right version of SOPS in the container (currently have the old version 1 in python).
2. Configure the dotenv-linter. Make it happy with the current .config/ files.
3. Install xe-cli into the docker image.
4. Make sure we are at the same stage as this spring.

TODO For mid term
5. Rename logger.sh into slf4sh.sh.
6. Extract it and semver into libraries to be published on my github account. Look into shell package managers.
7. Rework lib xapi-shell to remove MS Windows quirks. Streamline with new strategy of "out" function parameters.

TODO For long term (Finally caught up? Proceed with next steps...)
8. Get SSH key automatic generation working.
9. Attempt a transition to terraform.
10. Attempt a switch from FCOS to Talos. Apparently it even has terraform support.
11. Deploy 2 k8s control nodes
12. Deploy 2 k8s worker nodes
13. Deploy CNI calico
14. Configure geolocation configuration (multi-site storage constraints)
15. Deploy CSI smb
18. Deploy bluebook
19. Deploy XOA
20. Deploy Unify controller
16. Deploy external ingress controller (Can publish DNS updates to Namecheap)
17. Deploy internal ingress controller (Can configure Unboud on OPNsense)
21. Look for a centralized logging solution (SYSLOG server? - try to have better than emails)
21. Deploy Owncould (or similar - backup pictures on cellphones automatically)
22. Deploy Jellyfin
23. Deploy Arrrr
24. Deploy Home Assistant
