#!/bin/bash

# Sauce Robot Mobile - iOS Build Script
# This script builds the iOS app with embedded server

set -e

echo "🍎 Building Sauce Robot for iOS..."
echo "==================================="

# Check if we're in the right directory
if [ ! -f "package.json" ] || [ ! -d "ios" ]; then
    echo "❌ Error: Please run this script from the mobile-app directory"
    exit 1
fi

# Build the Spring Boot server (for reference, not needed for iOS native implementation)
echo "🏗️  Note: Using native iOS implementation instead of Spring Boot JAR"
echo "    The app includes a native HTTP server and SQLite database"

# Install dependencies
echo "📦 Installing dependencies..."
npm install

# Install iOS pods
echo "🍫 Installing CocoaPods..."
cd ios
pod install
cd ..

# Build the iOS app
echo "🔨 Building iOS app..."
npx react-native run-ios --configuration Release

echo ""
echo "✅ iOS build complete!"
echo "📱 The app should now be running on your iPhone"
echo ""
echo "To build for distribution:"
echo "  cd ios && xcodebuild -workspace SauceRobotMobile.xcworkspace -scheme SauceRobotMobile -configuration Release -archivePath build/SauceRobotMobile.xcarchive archive"
