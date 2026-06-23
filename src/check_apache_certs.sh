#!/usr/bin/env bash
# ===========================================================
# My Apache Certificate Checker
# Lists all domains, cert paths, and expiration dates
# Also verifies the private key exists, is readable,
# has correct permissions, and matches the certificate
# Works on Ubuntu/Debian and RHEL/CentOS/Fedora
# ===========================================================

set -e

if [[ "${EUID}" -ne 0 ]]; then
    echo "ERROR: Must run as root." >&2
    exit 1
fi

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

    KEYFILE=$(grep -i "SSLCertificateKeyFile" "$conf" | awk '{print $2}')
    [ -z "$KEYFILE" ] && KEYFILE="(no key file found)"

    echo "🌐 Domain:    $DOMAIN"
    echo "📜 Cert file: $CERTFILE"
    echo "🔑 Key file:  $KEYFILE"

    # --- Certificate checks ---
    if [ -f "$CERTFILE" ]; then
        openssl x509 -in "$CERTFILE" -noout -subject -issuer -dates | sed 's/^/    /'
    else
        echo "    ⚠  Cert file missing or not readable"
    fi

    # --- Key file checks ---
    if [ "$KEYFILE" = "(no key file found)" ]; then
        echo "    ⚠  SSLCertificateKeyFile not set in config"
    elif [ ! -f "$KEYFILE" ]; then
        echo "    ❌ Key file missing: $KEYFILE"
    else
        # Check permissions (should be 600)
        KEY_PERMS=$(stat -c "%a" "$KEYFILE")
        KEY_OWNER=$(stat -c "%U" "$KEYFILE")
        if [ "$KEY_PERMS" = "600" ]; then
            echo "    ✅ Key permissions: $KEY_PERMS (owner: $KEY_OWNER) — OK"
        else
            echo "    ⚠  Key permissions: $KEY_PERMS (owner: $KEY_OWNER) — expected 600"
        fi

        # Check the key is valid (not corrupt / wrong format)
        if ! openssl rsa -in "$KEYFILE" -check -noout 2>/dev/null; then
            echo "    ❌ Key file failed openssl rsa -check (corrupt or wrong format?)"
        else
            # Compare modulus of cert and key — must match for Apache to work
            CERT_MOD=$(openssl x509 -in "$CERTFILE" -noout -modulus 2>/dev/null | md5sum)
            KEY_MOD=$(openssl rsa  -in "$KEYFILE"  -noout -modulus 2>/dev/null | md5sum)
            if [ "$CERT_MOD" = "$KEY_MOD" ]; then
                echo "    ✅ Key matches certificate — OK"
            else
                echo "    ❌ KEY DOES NOT MATCH CERTIFICATE — Apache will fail to start!"
            fi
        fi
    fi

    echo "------------------------------------------------------------"
done
