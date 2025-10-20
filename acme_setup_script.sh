#!/bin/bash

# 🚀 ACME.sh Auto-Setup Script for SSL Certificate Automation
# Handles the transition to shorter certificate lifespans (47 days by 2029)

set -e  # Exit on any error

echo "🚀 Starting ACME.sh setup for automatic SSL certificate management..."

# Check if running as root (recommended)
if [[ $EUID -ne 0 ]]; then
   echo "⚠️  This script should be run as root for best results"
   echo "   Continue anyway? (y/N)"
   read -r response
   if [[ ! "$response" =~ ^[Yy]$ ]]; then
       exit 1
   fi
fi

# Configuration - CHANGE THESE VALUES
DOMAIN="example.com"              # Your main domain
WWW_DOMAIN=""                     # Your www domain (leave empty if not needed)
EMAIL="admin@example.com"         # Your email for Let's Encrypt notifications
WEBROOT="/var/www/html"           # Path to your web root
WEBSERVER="nginx"                 # nginx or apache2 (or httpd for RHEL)

echo "📧 Using email: $EMAIL"
if [ -n "$WWW_DOMAIN" ]; then
    echo "🌐 Domains: $DOMAIN, $WWW_DOMAIN"
else
    echo "🌐 Domain: $DOMAIN"
fi
echo "📁 Webroot: $WEBROOT"
echo "🖥️  Webserver: $WEBSERVER"

# Install required packages
echo "📦 Installing dependencies..."
if command -v apt-get >/dev/null; then
    # Debian/Ubuntu
    apt-get update
    apt-get install -y curl wget git cron
elif command -v yum >/dev/null; then
    # RHEL/CentOS
    yum install -y curl wget git cronie
    systemctl enable crond
    systemctl start crond
elif command -v pacman >/dev/null; then
    # Arch Linux
    pacman -S --noconfirm curl wget git cronie
fi

# Download and install acme.sh
echo "⬇️  Downloading acme.sh..."
cd /tmp
git clone https://github.com/acmesh-official/acme.sh.git
cd acme.sh

echo "🔧 Installing acme.sh..."
./acme.sh --install \
    --home /etc/acmesh \
    --config-home /etc/ssl/data \
    --cert-home /etc/ssl/certs \
    --accountemail "$EMAIL"

# Source the new alias
source ~/.bashrc 2>/dev/null || true
export PATH="/etc/acmesh:$PATH"

# Register with Let's Encrypt
echo "📋 Registering Let's Encrypt account..."
/etc/acmesh/acme.sh --register-account -m "$EMAIL"

# Issue certificate using webroot validation
echo "🔐 Requesting SSL certificate..."
if [ -n "$WWW_DOMAIN" ]; then
    # Certificate for both domain and www subdomain
    /etc/acmesh/acme.sh --issue \
        -d "$DOMAIN" \
        -d "$WWW_DOMAIN" \
        -w "$WEBROOT" \
        --reloadcmd "systemctl reload $WEBSERVER"
else
    # Certificate for domain only
    /etc/acmesh/acme.sh --issue \
        -d "$DOMAIN" \
        -w "$WEBROOT" \
        --reloadcmd "systemctl reload $WEBSERVER"
fi

# Install certificate to proper locations
echo "📄 Installing certificates..."
if [[ "$WEBSERVER" == "nginx" ]]; then
    # Nginx configuration
    CERT_PATH="/etc/ssl/certs/$DOMAIN"
    mkdir -p "$CERT_PATH"
    
    /etc/acmesh/acme.sh --install-cert -d "$DOMAIN" \
        --key-file "$CERT_PATH/key.pem" \
        --fullchain-file "$CERT_PATH/fullchain.pem" \
        --reloadcmd "systemctl reload nginx"
        
    echo "📝 Nginx SSL configuration example:"
    echo "   ssl_certificate     $CERT_PATH/fullchain.pem;"
    echo "   ssl_certificate_key $CERT_PATH/key.pem;"
    
elif [[ "$WEBSERVER" == "apache2" ]] || [[ "$WEBSERVER" == "httpd" ]]; then
    # Apache configuration  
    CERT_PATH="/etc/ssl/certs/$DOMAIN"
    mkdir -p "$CERT_PATH"
    
    /etc/acmesh/acme.sh --install-cert -d "$DOMAIN" \
        --cert-file "$CERT_PATH/cert.pem" \
        --key-file "$CERT_PATH/key.pem" \
        --fullchain-file "$CERT_PATH/fullchain.pem" \
        --reloadcmd "systemctl reload $WEBSERVER"
        
    echo "📝 Apache SSL configuration example:"
    echo "   SSLCertificateFile    $CERT_PATH/cert.pem"
    echo "   SSLCertificateKeyFile $CERT_PATH/key.pem"
    echo "   SSLCertificateChainFile $CERT_PATH/fullchain.pem"
fi

if [ -n "$WWW_DOMAIN" ]; then
    echo "📋 This certificate covers both $DOMAIN and $WWW_DOMAIN"
else
    echo "📋 This certificate covers $DOMAIN only"
fi

# Set up automatic renewal (acme.sh installs this automatically, but let's verify)
echo "⏰ Setting up automatic renewal..."
/etc/acmesh/acme.sh --cron --home /etc/acmesh

# Add backup cron job just in case
(crontab -l 2>/dev/null || echo "") | grep -v "acme.sh --cron" | { cat; echo "0 2 * * * /etc/acmesh/acme.sh --cron --home /etc/acmesh >/dev/null 2>&1"; } | crontab -

# Test configuration
echo "🧪 Testing certificate..."
/etc/acmesh/acme.sh --list

echo ""
echo "🎉 SUCCESS! ACME.sh is now set up and will automatically:"
echo "   ✅ Renew certificates every 60 days (well before expiration)"
echo "   ✅ Reload your webserver after renewal"
echo "   ✅ Handle the upcoming shorter certificate lifespans"
echo ""
echo "📍 Key locations:"
echo "   📂 acme.sh home: /etc/acmesh"
echo "   🔐 Certificates: /etc/ssl/certs/$DOMAIN"
echo "   📋 Config: /etc/ssl/data"
echo ""
echo "🔧 Useful commands:"
echo "   📋 List certificates: acme.sh --list"
echo "   🔄 Force renewal: acme.sh --renew -d $DOMAIN --force"
echo "   ℹ️  Show info: acme.sh --info -d $DOMAIN"
echo ""
echo "⚠️  IMPORTANT: Update your webserver config to use the certificate paths shown above!"

# Clean up
cd /
rm -rf /tmp/acme.sh
