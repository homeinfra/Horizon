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
- Configure root's email: <sol.demers.jeremfg.com@gmail.com>
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

## TODO

- Configure Periodic Snapshot
