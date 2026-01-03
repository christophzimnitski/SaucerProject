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

# Build the Spring Boot server
echo "🏗️  Building Spring Boot server..."
cd ../backend
mvn clean package -DskipTests
cd ../mobile-app

# Copy server JAR to iOS assets
echo "📦 Copying server to iOS assets..."
mkdir -p ios/SauceRobotMobile
cp ../backend/target/*.jar ios/SauceRobotMobile/server.jar

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
