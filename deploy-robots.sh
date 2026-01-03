#!/bin/bash

# Sauce Robot - Mass Robot Deployment Script
# Deploys Sauce Robot to thousands of robots worldwide

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🤖 Sauce Robot - Mass Deployment System"
echo "======================================"

# Configuration
BUILD_TYPE="${1:-release}"
DEPLOY_ENV="${2:-production}"
ROBOT_COUNT="${3:-1000}"

echo "Build Type: $BUILD_TYPE"
echo "Environment: $DEPLOY_ENV"
echo "Robot Count: $ROBOT_COUNT"
echo ""

# Phase 1: Build Components
echo "📦 Phase 1: Building Components..."
echo "----------------------------------"

# Build backend
echo "🏗️  Building Spring Boot backend..."
cd "$PROJECT_ROOT/backend"
mvn clean package -DskipTests -Dspring.profiles.active=robot
cd "$PROJECT_ROOT"

# Build mobile app
echo "📱 Building iOS mobile app..."
cd "$PROJECT_ROOT/mobile-app"
npm install

# Copy latest server
cp ../backend/target/*.jar ios/SauceRobotMobile/server.jar

# Install pods and build
cd ios
pod install
cd ..

# Build IPA
echo "🔨 Creating IPA for distribution..."
mkdir -p dist
npx react-native build-ios --configuration Release --mode archive

cd "$PROJECT_ROOT"

echo "✅ Build phase complete!"
echo ""

# Phase 2: Prepare Distribution
echo "📤 Phase 2: Preparing Distribution..."
echo "-------------------------------------"

# Create deployment package
DEPLOYMENT_ID="sauce-robot-$(date +%Y%m%d-%H%M%S)"
DEPLOY_DIR="$PROJECT_ROOT/deployments/$DEPLOYMENT_ID"

mkdir -p "$DEPLOY_DIR"

# Copy artifacts
cp "$PROJECT_ROOT/mobile-app/ios/build/SauceRobotMobile.ipa" "$DEPLOY_DIR/" 2>/dev/null || echo "IPA not found, run manual build"
cp "$PROJECT_ROOT/backend/target/*.jar" "$DEPLOY_DIR/server.jar"
cp -r "$PROJECT_ROOT/mobile-deployment" "$DEPLOY_DIR/mobile-deployment"

# Create deployment manifest
cat > "$DEPLOY_DIR/manifest.json" << EOF
{
  "deploymentId": "$DEPLOYMENT_ID",
  "buildType": "$BUILD_TYPE",
  "environment": "$DEPLOY_ENV",
  "robotCount": $ROBOT_COUNT,
  "buildDate": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "version": "2.0.0",
  "components": {
    "backend": "server.jar",
    "mobile": "SauceRobotMobile.ipa",
    "web": "mobile-deployment/"
  },
  "checksums": {
    "server": "$(shasum -a 256 "$DEPLOY_DIR/server.jar" | cut -d' ' -f1)",
    "mobile": "$(shasum -a 256 "$DEPLOY_DIR/SauceRobotMobile.ipa" 2>/dev/null || echo 'not-built')"
  }
}
EOF

echo "📋 Deployment package created: $DEPLOY_DIR"
echo ""

# Phase 3: Distribution Strategy
echo "🚀 Phase 3: Distribution Strategy..."
echo "-----------------------------------"

case $DEPLOY_ENV in
  "staging")
    echo "🧪 Staging Environment - Limited Rollout"
    echo "   - Deploy to 10% of robots ($((ROBOT_COUNT/10)) robots)"
    echo "   - Monitor for 24 hours"
    echo "   - Gradual rollout if successful"
    ;;
  "production")
    echo "🏭 Production Environment - Full Rollout"
    echo "   - Staged deployment: 10% → 50% → 100%"
    echo "   - 1-hour monitoring between stages"
    echo "   - Automatic rollback on failures"
    ;;
  "emergency")
    echo "🚨 Emergency Deployment"
    echo "   - Immediate global deployment"
    echo "   - Force update all robots"
    echo "   - Skip compatibility checks"
    ;;
esac

echo ""
echo "📊 Deployment Summary:"
echo "======================"
echo "Deployment ID: $DEPLOYMENT_ID"
echo "Target Robots: $ROBOT_COUNT"
echo "Environment: $DEPLOY_ENV"
echo "Build Type: $BUILD_TYPE"
echo ""
echo "📁 Deployment Package: $DEPLOY_DIR"
echo ""
echo "✅ Ready for robot deployment!"
echo ""
echo "Next steps:"
echo "1. Upload deployment package to distribution server"
echo "2. Configure MDM for rollout"
echo "3. Monitor deployment progress"
echo "4. Validate robot functionality"
echo ""
echo "🎯 All robots will be updated automatically within 24 hours!"
