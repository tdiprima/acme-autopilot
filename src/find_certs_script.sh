#!/bin/bash

# 🔍 Find Your SSL Certificate Files
# Run this to locate all your certificate files after ACME setup

echo "🔍 Searching for your SSL certificate files..."
echo

# Get domain from user or use example
read -p "Enter your domain (or press Enter for example.com): " DOMAIN
DOMAIN=${DOMAIN:-example.com}

echo "🌐 Looking for certificates for: $DOMAIN"
echo

# Function to show file info
show_file_info() {
    local file="$1"
    local description="$2"
    
    if [ -f "$file" ]; then
        echo "✅ $description"
        echo "   📁 Path: $file"
        echo "   📊 Size: $(du -h "$file" | cut -f1)"
        echo "   📅 Modified: $(stat -c %y "$file" 2>/dev/null || stat -f %Sm "$file" 2>/dev/null)"
        
        # Show certificate details if it's a cert file
        if [[ "$file" == *.pem ]] || [[ "$file" == *.crt ]]; then
            if openssl x509 -in "$file" -noout -subject -dates 2>/dev/null; then
                echo "   🔍 Certificate info above"
            fi
        fi
        echo
    else
        echo "❌ $description - NOT FOUND"
        echo "   📁 Expected path: $file"
        echo
    fi
}

echo "🔍 Standard acme.sh locations:"
echo "================================"

# Check acme.sh default locations
ACME_DIR="$HOME/.acme.sh/$DOMAIN"
show_file_info "$ACME_DIR/$DOMAIN.key" "Private Key (acme.sh storage)"
show_file_info "$ACME_DIR/$DOMAIN.cer" "Certificate (acme.sh storage)"
show_file_info "$ACME_DIR/fullchain.cer" "Full Chain (acme.sh storage)"
show_file_info "$ACME_DIR/ca.cer" "CA Certificate (acme.sh storage)"

echo "🔍 Script-installed locations:"
echo "==============================="

# Check where our script should have installed them
CERT_DIR="/etc/ssl/certs/$DOMAIN"
show_file_info "$CERT_DIR/key.pem" "Private Key (for web server)"
show_file_info "$CERT_DIR/fullchain.pem" "Full Chain (for web server)"
show_file_info "$CERT_DIR/cert.pem" "Certificate (for Apache)"

echo "🔍 Alternative common locations:"
echo "================================"

# Check other common locations
show_file_info "/etc/ssl/private/$DOMAIN.key" "Private Key (alternative)"
show_file_info "/etc/ssl/certs/$DOMAIN.crt" "Certificate (alternative)"
show_file_info "/etc/ssl/certs/$DOMAIN.pem" "Certificate (alternative)"

echo "🔍 Search results:"
echo "=================="

# Search for any files containing the domain name
echo "📂 All files containing '$DOMAIN':"
find /etc -name "*$DOMAIN*" -type f 2>/dev/null | head -10
find ~/.acme.sh -name "*$DOMAIN*" -type f 2>/dev/null | head -10

echo
echo "📂 All .pem files in /etc/ssl:"
find /etc/ssl -name "*.pem" -type f 2>/dev/null | head -10

echo
echo "🔧 What you need for your web server:"
echo "====================================="
echo "For NGINX, you typically need:"
echo "   ssl_certificate      /path/to/fullchain.pem;"
echo "   ssl_certificate_key  /path/to/private.key;"
echo
echo "For Apache, you typically need:"
echo "   SSLCertificateFile    /path/to/cert.pem"
echo "   SSLCertificateKeyFile /path/to/private.key"
echo "   SSLCertificateChainFile /path/to/fullchain.pem"
echo
echo "🎯 Next steps:"
echo "1. Identify which files exist from the list above"
echo "2. Use the paths in your web server configuration"
echo "3. Test with: nginx -t (for nginx) or apache2ctl configtest (for apache)"
