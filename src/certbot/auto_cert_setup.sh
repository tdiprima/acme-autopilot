#!/usr/bin/env bash
# ===========================================================
# My All-in-One Cert Automation Script
# Works on Red Hat, CentOS, Fedora, Ubuntu, Debian
# ===========================================================

set -e

echo "🔍 Detecting OS..."
if [ -f /etc/redhat-release ]; then
    OS="redhat"
    WEB_SERVICE="httpd"
    echo "🐧 Detected Red Hat-based system."
elif [ -f /etc/debian_version ]; then
    OS="ubuntu"
    WEB_SERVICE="apache2"
    echo "🦊 Detected Ubuntu/Debian-based system."
else
    echo "❌ Unsupported OS. Exiting."
    exit 1
fi

read -rp "💌 Enter email address: " EMAIL
read -rp "🌐 Enter domain name (e.g. server.example.com): " DOMAIN
read -rp "🗝️ Enter your EAB Key ID: " EAB_KID
read -rp "🔑 Enter your EAB HMAC Key: " EAB_HMAC

echo "⚙️ Installing dependencies..."
if [ "$OS" = "redhat" ]; then
    # Install EPEL repository for Certbot
    sudo yum install -y epel-release
    sudo yum install -y certbot python3-certbot-apache
else
    sudo apt update -y
    sudo apt install -y snapd

    echo "🔩 Installing Certbot via Snap..."
    sudo snap install core
    sudo snap refresh core
    sudo snap install --classic certbot
    sudo ln -sf /snap/bin/certbot /usr/bin/certbot
fi

echo "📜 Requesting certificate for $DOMAIN..."
sudo certbot certonly \
    --standalone \
    --non-interactive \
    --agree-tos \
    --email "$EMAIL" \
    --server https://acme.sectigo.com/v2/InCommonRSAOV \
    --eab-kid "$EAB_KID" \
    --eab-hmac-key "$EAB_HMAC" \
    --domain "$DOMAIN" \
    --cert-name "$DOMAIN" \
    --deploy-hook "systemctl restart $WEB_SERVICE"

echo "🧪 Testing renewal..."
sudo certbot renew --dry-run

echo "⏰ Checking for systemd auto-renew timer..."
if systemctl list-timers | grep -q certbot; then
    echo "✅ Systemd timer already active."
else
    echo "⚡ Creating daily cron job for renewal..."
    (sudo crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet --deploy-hook 'systemctl restart $WEB_SERVICE'") | sudo crontab -
fi

echo "🎉 Done! Certificate for $DOMAIN installed and auto-renew configured."
echo "🔒 Your cert files live here: /etc/letsencrypt/live/$DOMAIN/"
