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
    echo "🌐 Access from your phone using your computer's IP address on port 8080"
    echo ""
    echo "To stop: docker-compose down"
    echo "To view logs: docker-compose logs -f"
else
    echo "❌ Application failed to start. Check logs:"
    docker-compose logs
fi
