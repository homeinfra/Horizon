# Kosmos

VM running on demers-sol, used for the following purpose:

- HTPC connected to the TV in the living room
- Future: Kubernetes worker node under WSL, with access to the GPU (Frigate
  container).

## Configuration

This VM is not configured by a scipt. The following actions need to be performed
once Windows is installed.

The VM itself is created by running /src/bootstrap/01-vm/Kosmos/setup

1. Configure hostname to Kosmos
1. Install Remote Mouse
1. Configure Remote Mouse so it works on login screen
    1. Create a new service under Window's Task Sceduler
    1. Trigger: On Startup
    1. Start program: "Remote Mouse.exe"
    1. Privileges: Execute with all privileges
    1. Execute as: NT Authority\System
1. Join to Active Directory
1. Install Chrome for all users
1. Install XenServer agent
1. Install nVidia drivers
1. Configure Primary display as TV
1. Increase Window's text size so it's lisible as a 10-foot interface
1. Connect bluetooth keyboard
1. Test that IR remote works
1. Make sure that Bluray drive shows up
1.
