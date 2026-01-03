#!/bin/bash

# Sauce Robot - Build and Run Script
# This script packages the entire application into a Docker container

set -e

echo "🍅 Building Sauce Robot for Mobile Testing..."
echo "=============================================="

# Clean up previous builds
echo "🧹 Cleaning up previous builds..."
docker-compose down --volumes --remove-orphans 2>/dev/null || true
docker system prune -f

# Build the Docker image
echo "🏗️  Building Docker image..."
docker-compose build --no-cache

# Create data directory if it doesn't exist
mkdir -p ../data

echo "🚀 Starting Sauce Robot..."
echo "=========================="
echo "Once running, access at: http://localhost:8080"
echo "Or from your phone: http://[YOUR_COMPUTER_IP]:8080"
echo ""
echo "To find your computer's IP address:"
echo "  - macOS: ifconfig | grep inet"
echo "  - Linux: ip addr show"
echo "  - Windows: ipconfig"
echo ""

docker-compose up -d

echo "⏳ Waiting for application to start..."
sleep 10

# Check if the application is running
if curl -f http://localhost:8080/api/recipes &>/dev/null; then
    echo "✅ Sauce Robot is running!"
    echo ""
    echo "📱📱📱 ACCESS FROM YOUR IPHONE 📱📱📱"
    echo "=========================================="

    # Detect OS and show IP
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        WIFI_IP=$(ifconfig en0 2>/dev/null | grep inet | grep -v inet6 | awk '{print $2}')
        if [ ! -z "$WIFI_IP" ]; then
            echo "🍎 macOS WiFi IP (iPhone on same network):"
            echo "   🔗 http://$WIFI_IP:8080"
            echo ""
        fi
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
        # Windows
        echo "🪟 Windows detected - run 'ipconfig' to find your IP"
        echo "   Look for wireless adapter (192.168.x.x)"
        echo "   Then visit: http://[YOUR_IP]:8080"
        echo ""
    else
        # Linux
        LINUX_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
        if [ ! -z "$LINUX_IP" ]; then
            echo "🐧 Linux IP:"
            echo "   🔗 http://$LINUX_IP:8080"
            echo ""
        fi
    fi

    echo "📋 How to access:"
    echo "   1. Copy the URL above"
    echo "   2. Open Safari on your iPhone"
    echo "   3. Paste and visit the URL"
    echo ""
    echo "🚀 The Sauce Robot interface will load in your browser!"
    echo ""
    echo "📊 Management:"
    echo "   Stop: docker-compose down"
    echo "   Logs: docker-compose logs -f"
else
    echo "❌ Application failed to start. Check logs:"
    docker-compose logs
fi
