#!/bin/bash
# Certbot doesn't care whether the package is called apache2 (Debian/Ubuntu) or httpd (RHEL/CentOS/Alma/Rocky).
# The --apache flag just tells Certbot to use the Apache plugin.
# No --httpd flag exists. It's always --apache.

# Run Certbot to obtain an SSL certificate using Apache
sudo certbot run --apache \
  --agree-tos \
  --email you@example.com \
  --server https://acme.sectigo.com/v2/InCommonRSAOV \
  --eab-kid <your-key-id> \
  --eab-hmac-key <your-hmac-key> \
  -d yourserver.example.com

# Remotely: check the expiration date of the certificate
curl -vI https://yourserver.example.com 2>&1 | grep -i "expire date"
