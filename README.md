# 🍅 Sauce Robot

A recipe management application for creating and managing sauce recipes, designed to run on thousands of robots worldwide.

## 🚀 Quick Start

### For iPhone Users (Recommended):
```bash
cd mobile-app
./build-ios.sh
```
The Sauce Robot runs directly on your iPhone with its own local server!

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
