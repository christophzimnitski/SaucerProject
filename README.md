# 🍅 Sauce Robot

A recipe management application for creating and managing sauce recipes, designed to run on thousands of robots worldwide.

## 🚀 Quick Start

### For iPhone Users (Native iOS App - Requires Mac Computer):
**⚠️ IMPORTANT:** You need a Mac computer with Xcode to build the native iOS app!

```bash
# On your Mac computer:
cd mobile-app

# If you have build errors, run this first:
./clean-fix.sh

# Then build:
./build-ios.sh
```
The Sauce Robot will run **entirely on your iPhone** with:
- ✅ **No external computer needed** - everything runs on the phone
- ✅ **Native iOS performance** - smooth and responsive
- ✅ **Offline operation** - works without internet
- ✅ **Isolated data** - your recipes stay on your phone

### Alternative: Docker Container (Web Access):
```bash
# On any computer with Docker:
cd mobile-deployment
./build-and-run.sh
```
Then access from your iPhone at: `http://[COMPUTER_IP]:8080`

### Alternative: Web Version on iPhone:
```bash
# On any computer:
cd frontend
npm install
npm start
```
Then access from your iPhone at: `http://[COMPUTER_IP]:3000`

### For Computer-Based Testing:
```bash
cd mobile-deployment
./build-and-run.sh
```
Then access from your phone at: `http://[YOUR_COMPUTER_IP]:8080`

### For Mass Robot Deployment:
```bash
./deploy-robots.sh production 1000
```
Deploys to thousands of robots automatically!

## 🏗️ Development

### Backend (Spring Boot)
```bash
cd backend
mvn spring-boot:run
```

### Frontend (React)
```bash
cd frontend
npm start
```

### Mobile App (iOS)
```bash
cd mobile-app
./build-ios.sh
```

## 📁 Project Structure

- `backend/` - Spring Boot API server with H2 database
- `frontend/` - React web application
- `mobile-app/` - Native iOS app (runs locally on devices)
- `mobile-deployment/` - Docker container for testing
- `robot-deployment/` - Mass deployment tools and documentation
- `data/` - H2 database files (auto-created)

## 🤖 Robot Features

- **Local Operation** - Each robot runs independently
- **Isolated Database** - No shared data conflicts
- **Web Interface** - Access via any browser
- **Auto-Updates** - OTA updates for thousands of robots
- **Self-Healing** - Automatic restart on failures
- **Low Power** - Optimized for continuous operation

## 📊 Architecture

```
Robot Device (iPhone/iPad)
├── Native iOS App
├── Embedded Spring Boot Server
├── Isolated H2 Database
└── Web Interface (React)
```

Each robot is completely self-contained and can operate independently!
