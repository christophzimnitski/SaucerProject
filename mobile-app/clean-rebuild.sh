#!/bin/bash

# Sauce Robot iOS - Clean Rebuild Script
# Fixes common Xcode and CocoaPods issues

set -e

echo "🧹 Cleaning Sauce Robot iOS build..."
echo "======================================"

# Check if we're in the mobile-app directory
if [ ! -f "package.json" ] || [ ! -d "ios" ]; then
    echo "❌ Error: Please run this script from the mobile-app directory"
    exit 1
fi

echo "📦 Installing JavaScript dependencies..."
npm install

echo "🗑️  Cleaning CocoaPods cache..."
cd ios
rm -rf Pods Podfile.lock

echo "📱 Installing iOS pods with correct targets..."
pod install

echo "✅ Clean rebuild complete!"
echo ""
echo "🎯 Next Steps:"
echo "=============="
echo "1. Open Xcode: open SauceRobotMobile.xcworkspace"
echo "2. Clean build: Product → Clean Build Folder (⇧⌘K)"
echo "3. Build: Product → Build (⌘B)"
echo "4. Run: Product → Run (⌘R) with your iPhone connected"
echo ""
echo "🚀 The app should now build successfully!"
echo ""
echo "Note: Most warnings you see are from third-party libraries"
echo "and won't prevent the build from succeeding."
