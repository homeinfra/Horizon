# Demers-halley

## Steps taken during installation

- Chosen a password for user truenas_admin
- Chosen a drive xdva (20 TiB)
- Keep defaults for network (DHCP)

## Steps taken after installation

- Followed wizard to create my ZFS pool named "Data"
  - No other vdevs than the Data one.
  - Ignored warning about non-unique serial numbers for the disks
- Configured network settings:
  - Hostname: halley
  - domain: demers.jeremfg.com
- Configure root's email: <jeremfg@gmail.com>
- Configure email
  - Method: SMTP
  - From Email: <halley@demers.jeremfg.com>
  - From Name: Halley
  - Outgoing Mail Server: smtp.gmail.com
  - Mail Server Port: 587
  - Security: TLS (STARTTLS)
  - SMTP Authentication (checked)
  - Username: ${SSMTP_USER}
  - Password: ${SSMTP_PASS}
- Tested emails with success
- Configured NTP servers: 0.ca.pool.ntp.org, 1.ca.pool.ntp.org, 2.ca.pool.ntp.org
- Configured Localization Settings:
  - Console Keyboard Layout: French (Canada) (ca)
  - Timezone: America/Toronto
- GUI Settings
  - Web Interface HTTP->HTTPS Redirect (checked)
  - Show Console Messages (checked)
- Configured S.M.A.R.T Test
  - Short on all 6 disk using a "Custom" schedule. Every Saturday at 8 AM
  - Long on all 6 disk using the "Monthly" schedule
- Make sure only one DNS server is configured: 192.168.16.11
- Connected to Active Directory
- Increased MTU to 9216
- Enable SSH
- Enable SMB
- Enabled truenas_admin for ssh login
- Created dataset: Public, Group, User, Infra and Vault, with basic ACL permissions
- Limit DNS servers to NSSDC only, to solve alerts about AD
- Extend GUI Session timeout to 24 hours (86400 seconds)
- Using Windows RSAT, edit paths for mapped drives
- Using Windows Security, fix permissions on /User/*, /Group/* and /Public
- Using Windows Security, fix permissions on /Infra and /Vault

## TODO

- Install xen guest tools
- Configure off-site replication
- Configure Periodic Snapshot
