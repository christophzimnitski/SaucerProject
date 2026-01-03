#!/bin/bash

# Sauce Robot - IP Address Finder
# Helps you find your computer's IP address for mobile access

echo "🌐 Finding your computer's IP address..."
echo "=========================================="
echo ""

# Detect OS
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    echo "🍎 macOS detected"
    echo ""

    # Get WiFi IP
    WIFI_IP=$(ifconfig en0 | grep inet | grep -v inet6 | awk '{print $2}')
    if [ ! -z "$WIFI_IP" ]; then
        echo "📱 Your WiFi IP (for iPhone on same network):"
        echo "   http://$WIFI_IP:8080"
        echo ""
    fi

    # Get Ethernet IP
    ETH_IP=$(ifconfig en1 2>/dev/null | grep inet | grep -v inet6 | awk '{print $2}')
    if [ ! -z "$ETH_IP" ]; then
        echo "🔌 Your Ethernet IP:"
        echo "   http://$ETH_IP:8080"
        echo ""
    fi

elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
    # Windows
    echo "🪟 Windows detected"
    echo ""
    echo "Run this command in Command Prompt or PowerShell:"
    echo "   ipconfig"
    echo ""
    echo "Look for your wireless adapter IP address (usually starts with 192.168.x.x)"
    echo "Then visit: http://[YOUR_IP]:8080"
    echo ""

else
    # Linux
    echo "🐧 Linux detected"
    echo ""

    # Get IP from various interfaces
    INTERFACES=$(hostname -I)
    for IP in $INTERFACES; do
        if [[ $IP =~ ^192\.168\. ]] || [[ $IP =~ ^10\. ]] || [[ $IP =~ ^172\. ]]; then
            echo "📱 Local network IP:"
            echo "   http://$IP:8080"
            echo ""
            break
        fi
    done
fi

echo "📋 Instructions:"
echo "================"
echo "1. Copy one of the URLs above"
echo "2. Open Safari on your iPhone"
echo "3. Paste the URL and go!"
echo ""
echo "🔍 If none of these work:"
echo "   - Make sure your iPhone is on the same WiFi network"
echo "   - Try a different IP address from the list"
echo "   - Check firewall settings"
echo ""
echo "✨ The Sauce Robot should load in your browser!"
