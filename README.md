<!-- wget -O - https://get.acme.sh | sh -s email=<EMAIL_ADDRESS> -->

# acme-autopilot

Automate SSL/TLS certificate management with Certbot.

## Why Automate?

Certificate lifespans are steadily decreasing, making automation essential. Manual certificate renewal is error-prone and time-consuming.

## Primary Tool: Certbot

This repository uses **Certbot** for automated certificate acquisition and renewal. The scripts support:

- Cross-platform deployment (Red Hat, CentOS, Fedora, Ubuntu, Debian)
- InCommon/Sectigo ACME integration with EAB (External Account Binding)
- Automated web server configuration
- Scheduled renewals via systemd timers or cron

## Quick Start

### Automated Setup

The main setup script handles everything:

```sh
cd src/certbot
sudo ./auto_cert_setup.sh
```

This script will:

1. Detect your OS (Red Hat-based or Debian-based)
2. Install Certbot (via EPEL on RHEL or Snap on Ubuntu/Debian)
3. Request certificates using your configured ACME server
4. Configure automatic renewals
5. Set up post-renewal hooks

### Post-Renewal Actions

The `run_after.sh` script handles post-renewal tasks like web server restarts.

## Alternative: acme.sh

Legacy scripts using acme.sh are available in `src/acme/` but Certbot is now the recommended approach.

## License

See [LICENSE](LICENSE) for details.

<br>
