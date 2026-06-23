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

    # Resolve symlinks so stat and openssl operate on the real file
    REAL_CERTFILE=$(readlink -f "$CERTFILE" 2>/dev/null || echo "$CERTFILE")
    REAL_KEYFILE=$(readlink -f "$KEYFILE" 2>/dev/null || echo "$KEYFILE")

    echo "🌐 Domain:    $DOMAIN"
    echo "📜 Cert file: $CERTFILE"
    [ "$REAL_CERTFILE" != "$CERTFILE" ] && echo "    ↳ resolves to: $REAL_CERTFILE"
    echo "🔑 Key file:  $KEYFILE"
    [ "$REAL_KEYFILE" != "$KEYFILE" ] && echo "    ↳ resolves to: $REAL_KEYFILE"

    # --- Certificate checks ---
    if [ -f "$REAL_CERTFILE" ]; then
        openssl x509 -in "$REAL_CERTFILE" -noout -subject -issuer -dates | sed 's/^/    /'
    else
        echo "    ⚠  Cert file missing or not readable"
    fi

    # --- Key file checks ---
    if [ "$KEYFILE" = "(no key file found)" ]; then
        echo "    ⚠  SSLCertificateKeyFile not set in config"
    elif [ ! -f "$REAL_KEYFILE" ]; then
        echo "    ❌ Key file missing: $REAL_KEYFILE"
    else
        # Check permissions on the real file (not the symlink)
        KEY_PERMS=$(stat -c "%a" "$REAL_KEYFILE")
        KEY_OWNER=$(stat -c "%U" "$REAL_KEYFILE")
        if [ "$KEY_PERMS" = "600" ]; then
            echo "    ✅ Key permissions: $KEY_PERMS (owner: $KEY_OWNER) — OK"
        else
            echo "    ⚠  Key permissions: $KEY_PERMS (owner: $KEY_OWNER) — expected 600"
        fi

        # Detect key algorithm (RSA, EC, or other)
        if openssl ec -in "$REAL_KEYFILE" -noout 2>/dev/null; then
            ALGO="EC (Elliptic Curve)"
        elif openssl rsa -in "$REAL_KEYFILE" -check -noout 2>/dev/null; then
            ALGO="RSA"
        else
            ALGO="unknown"
        fi

        # Show the key algorithm and curve/size details
        ALGO_DETAIL=$(openssl pkey -in "$REAL_KEYFILE" -noout -text 2>/dev/null \
            | grep -E "Private-Key|NIST CURVE|ASN1 OID" \
            | sed 's/^ *//' | tr '\n' ' ')
        echo "    🔐 Key algorithm: $ALGO  ($ALGO_DETAIL)"

        # Check cert algorithm too
        CERT_ALGO=$(openssl x509 -in "$REAL_CERTFILE" -noout -text 2>/dev/null \
            | grep "Public Key Algorithm" | head -1 | sed 's/.*: //')
        echo "    📋 Cert algorithm: $CERT_ALGO"

        # Compare public keys — works for both RSA and EC
        CERT_PUBKEY=$(openssl x509 -in "$REAL_CERTFILE" -noout -pubkey 2>/dev/null | md5sum)
        KEY_PUBKEY=$(openssl pkey  -in "$REAL_KEYFILE"  -pubout 2>/dev/null | md5sum)
        if [ "$CERT_PUBKEY" = "$KEY_PUBKEY" ]; then
            echo "    ✅ Key matches certificate — OK"
        else
            echo "    ❌ KEY DOES NOT MATCH CERTIFICATE — Apache will fail to start!"
        fi
    fi

    echo "------------------------------------------------------------"
done

# sudo certbot certificates
# That will show you exactly which cert and key certbot considers the current valid pair for your domain.
