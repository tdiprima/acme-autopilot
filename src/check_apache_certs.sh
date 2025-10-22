#!/usr/bin/env bash
# ===========================================================
# My Apache Certificate Checker
# Lists all domains, cert paths, and expiration dates
# Works on Ubuntu/Debian and RHEL/CentOS/Fedora
# ===========================================================

set -e

APACHE_DIR=""
if [ -d /etc/apache2/sites-enabled ]; then
    APACHE_DIR="/etc/apache2/sites-enabled"
elif [ -d /etc/httpd/conf.d ]; then
    APACHE_DIR="/etc/httpd/conf.d"
else
    echo "❌ Could not find Apache config directory."
    exit 1
fi

echo "🔍 Scanning Apache configs in: $APACHE_DIR"
echo "------------------------------------------------------------"

# Find every config file that mentions SSL
for conf in $(grep -lR "SSLCertificateFile" "$APACHE_DIR"); do
    echo "📁 Config file: $conf"
    DOMAIN=$(grep -i "ServerName" "$conf" | awk '{print $2}')
    [ -z "$DOMAIN" ] && DOMAIN="(no ServerName found)"
    CERTFILE=$(grep -i "SSLCertificateFile" "$conf" | awk '{print $2}')
    [ -z "$CERTFILE" ] && CERTFILE="(no cert file found)"

    echo "🌐 Domain: $DOMAIN"
    echo "📜 Cert file: $CERTFILE"

    if [ -f "$CERTFILE" ]; then
        openssl x509 -in "$CERTFILE" -noout -subject -issuer -dates | sed 's/^/    /'
    else
        echo "    ⚠️  Cert file missing or not readable"
    fi
    echo "------------------------------------------------------------"
done
