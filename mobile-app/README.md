# 🍅 Sauce Robot - iOS Mobile App

A **completely self-contained** iOS app that runs the entire Sauce Robot system on your iPhone with **zero external dependencies**.

## 🎯 What This App Does

Unlike web-based solutions that require a computer running a server, this native iOS app:

- ✅ **Embeds everything** - HTTP server, database, and UI all in one app
- ✅ **Runs on your phone** - No computer needed ever
- ✅ **Works offline** - No internet required
- ✅ **Isolated data** - Your recipes stay on your phone
- ✅ **Native performance** - Smooth iOS experience

## 🏗️ Architecture

```
iPhone App
├── React Native UI (JavaScript)
├── Native iOS Bridge
│   ├── GCDWebServer (HTTP Server)
│   └── SQLite Database
└── Embedded WebView (displays UI)
```

The app contains:
- **HTTP Server:** GCDWebServer running on `http://localhost:8080`
- **Database:** SQLite with the same schema as the Spring Boot version
- **UI:** Same React interface, served from the embedded server

## 🚀 Building for iPhone

### Prerequisites
- **Mac computer** with Xcode 14+
- **iOS device** (iPhone/iPad) for testing
- **Apple Developer Account** (for device deployment)

### Build Steps
```bash
# 1. Install dependencies
npm install

# 2. Fix any issues and install iOS pods
./clean-fix.sh

# 3. Build and run
npm run ios
# or
./build-ios.sh
```

### Xcode Manual Build
1. Open `ios/SauceRobotMobile.xcodeproj` in Xcode
2. Connect your iPhone
3. Select your device as target
4. Build and run (⌘R)

## 📱 Using the App

1. **Launch the app** on your iPhone
2. **Wait for initialization** (embedded server starts automatically)
3. **Use normally** - create/edit recipes, start sauce making
4. **All data persists** on your phone between sessions

## 🔧 Technical Details

### Embedded Server APIs
The app implements the same REST API as the Spring Boot version:
- `GET /api/recipes` - List all recipes
- `POST /api/recipes` - Create new recipe
- `PUT /api/recipes/{id}` - Update recipe
- `POST /api/recipes/start-sauce/{id}` - Start sauce making

### Database Schema
```sql
CREATE TABLE recipe (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    ingredients TEXT NOT NULL
);
```

### Permissions
The app requests minimal permissions:
- Local networking (for embedded server)
- Local storage (for database)

## 🚀 Deployment for Mass Robot Use

### Build for Enterprise Distribution
```bash
# Build IPA for enterprise deployment
npm run build-ipa

# The IPA file will be at:
# ios/build/SauceRobotMobile.xcarchive
```

### Enterprise Deployment
1. Upload IPA to MDM server (Mobile Device Management)
2. Configure enterprise app distribution
3. Deploy to robot devices over-the-air
4. Robots auto-install and run independently

## 🔍 Troubleshooting

### Build Issues
```bash
# Clean and rebuild
cd ios
rm -rf build Pods Podfile.lock
pod install
cd ..
npm run ios
```

### App Won't Start
- Check device storage space
- Restart the app
- Check device logs in Xcode

### Server Issues
- The embedded server runs on `http://localhost:8080`
- Check Xcode console for server logs
- Restart the app to restart the server

## 🎉 Success!

Once built and installed, you have a **completely self-contained** Sauce Robot system running entirely on your iPhone. No external computers, no network dependencies, no cloud services - just pure, native iOS awesomeness! 🤖📱✨
