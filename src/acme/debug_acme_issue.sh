#!/bin/bash

# 🐛 Debug ACME Certificate Issue
# This script helps diagnose why your certificate request failed

read -p "Enter your domain (or press Enter for example.com): " DOMAIN
DOMAIN=${DOMAIN:-example.com}
WEBROOT="/var/www/html"

echo "🔍 Debugging ACME certificate issue for $DOMAIN"
echo

# Check if domain resolves to this server
echo "1⃣ Checking DNS resolution..."
# TODO: This is wrong - prints name and IP:
DOMAIN_IP=$(dig +short $DOMAIN)
SERVER_IP=$(curl -s ifconfig.me || curl -s ipinfo.io/ip)

echo "   Domain $DOMAIN resolves to: $DOMAIN_IP"
echo "   This server's public IP: $SERVER_IP"

if [ "$DOMAIN_IP" = "$SERVER_IP" ]; then
    echo "   ✅ DNS looks correct!"
else
    echo "   ❌ DNS mismatch! Domain doesn't point to this server."
    echo "   🔧 Fix: Update your DNS A record to point to $SERVER_IP"
fi
echo

# Check web server is running and accessible
echo "2⃣ Checking web server..."
if systemctl is-active --quiet apache2; then
    echo "   ✅ Apache2 is running"
    WEBSERVER="apache2"
elif systemctl is-active --quiet httpd; then
    echo "   ✅ Apache (httpd) is running"
    WEBSERVER="httpd"
elif systemctl is-active --quiet nginx; then
    echo "   ✅ Nginx is running"
    WEBSERVER="nginx"
else
    echo "   ❌ No web server appears to be running"
    echo "   🔧 Fix: Start your web server (apache2/nginx)"
fi
echo

# Check port 80 accessibility
echo "3⃣ Checking port 80 accessibility..."
if netstat -tlnp | grep -q ":80 "; then
    echo "   ✅ Something is listening on port 80"
    
    # Test HTTP access
    if curl -sI http://$DOMAIN/ >/dev/null 2>&1; then
        echo "   ✅ HTTP request to $DOMAIN successful"
    else
        echo "   ❌ HTTP request to $DOMAIN failed"
        echo "   🔧 Check firewall/network connectivity"
    fi
else
    echo "   ❌ Nothing listening on port 80"
    echo "   🔧 Fix: Start web server or check configuration"
fi
echo

# Check webroot directory
echo "4⃣ Checking webroot directory..."
if [ -d "$WEBROOT" ]; then
    echo "   ✅ Webroot $WEBROOT exists"
    
    if [ -w "$WEBROOT" ]; then
        echo "   ✅ Webroot is writable"
    else
        echo "   ❌ Webroot is not writable"
        echo "   🔧 Fix: chmod 755 $WEBROOT"
    fi
    
    # Test challenge file creation
    TEST_FILE="$WEBROOT/.well-known/acme-challenge/test"
    mkdir -p "$(dirname "$TEST_FILE")"
    if echo "test" > "$TEST_FILE" 2>/dev/null; then
        echo "   ✅ Can create challenge files"
        rm -f "$TEST_FILE"
        rmdir "$WEBROOT/.well-known/acme-challenge" 2>/dev/null
        rmdir "$WEBROOT/.well-known" 2>/dev/null
    else
        echo "   ❌ Cannot create challenge files"
        echo "   🔧 Fix: Check permissions on $WEBROOT"
    fi
else
    echo "   ❌ Webroot $WEBROOT does not exist"
    echo "   🔧 Fix: Create directory or use correct webroot path"
fi
echo

# Check firewall
echo "5⃣ Checking firewall..."
if command -v ufw >/dev/null; then
    UFW_STATUS=$(ufw status | grep "Status:")
    echo "   UFW Status: $UFW_STATUS"
    if ufw status | grep -q "80/tcp"; then
        echo "   ✅ Port 80 allowed in UFW"
    else
        echo "   ❌ Port 80 not explicitly allowed in UFW"
        echo "   🔧 Fix: ufw allow 80/tcp"
    fi
fi

if command -v iptables >/dev/null; then
    if iptables -L INPUT | grep -q "ACCEPT.*tcp.*80"; then
        echo "   ✅ Port 80 allowed in iptables"
    else
        echo "   ⚠  Port 80 rules unclear in iptables"
    fi
fi
echo

# Show recent acme.sh logs
echo "6⃣ Recent ACME logs..."
if [ -f ~/.acme.sh/acme.sh.log ]; then
    echo "   📋 Last 20 lines of ACME log:"
    tail -20 ~/.acme.sh/acme.sh.log | sed 's/^/   /'
else
    echo "   ❌ No ACME log file found"
fi
echo

# Provide next steps
echo "🎯 Recommended next steps:"
echo

if [ "$DOMAIN_IP" != "$SERVER_IP" ]; then
    echo "1. 🌐 Fix DNS: Point $DOMAIN to $SERVER_IP"
    echo "2. ⏳ Wait for DNS propagation (can take up to 48 hours)"
    echo "3. 🔄 Retry certificate request"
else
    echo "1. 🔄 Retry with debug mode:"
    echo "   acme.sh --issue -d $DOMAIN -w $WEBROOT --debug 2"
    echo
    echo "2. 🌐 Or try standalone mode (stops web server temporarily):"
    echo "   systemctl stop $WEBSERVER"
    echo "   acme.sh --issue -d $DOMAIN --standalone"
    echo "   systemctl start $WEBSERVER"
    echo
    echo "3. 📞 Or contact your university IT department if this is a managed server"
fi

echo
echo "🔧 Quick fixes to try:"
echo "   • Restart web server: systemctl restart $WEBSERVER"
echo "   • Open firewall: ufw allow 80/tcp && ufw allow 443/tcp"  
echo "   • Check permissions: chmod -R 755 $WEBROOT"
echo "   • Test manually: curl -I http://$DOMAIN/"
