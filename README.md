# Sauce Robot

A recipe manager for a sauce-making robot. You create recipes (a name and a
list of ingredients), edit them, and send one to the robot to start. This is a
prototype: starting a recipe currently returns a status message and does not
yet drive any hardware.

The same recipe API is built two ways:

- **Server version:** a Spring Boot backend with an H2 database, and a React
  web frontend.
- **iPhone version:** a React Native app that runs a small web server on the
  phone itself (GCDWebServer), stores recipes on the device, and serves the
  same React frontend. It works offline and needs no separate computer.

## Folders

| Folder               | Contents                                        |
|----------------------|-------------------------------------------------|
| `backend/`           | Spring Boot REST API (Java 17, Maven)           |
| `frontend/`          | React web interface                             |
| `mobile-app/`        | React Native iOS app with the on-device server  |
| `mobile-deployment/` | Docker setup for running the web version        |
| `robot-deployment/`  | Notes on packaging the app for robot devices    |

## API

| Method | Path                            | Action                     |
|--------|---------------------------------|----------------------------|
| GET    | `/api/recipes`                  | List recipes               |
| POST   | `/api/recipes`                  | Create a recipe            |
| PUT    | `/api/recipes/{id}`             | Update a recipe            |
| POST   | `/api/recipes/start-sauce/{id}` | Start making a recipe      |
| GET    | `/api/recipes/stream`           | Live updates (server only) |

## Running the server version

Requires Java 17 and Node.js.

```bash
cd backend
./mvnw spring-boot:run
```

In a second terminal:

```bash
cd frontend
npm install
npm start
```

The web app opens at http://localhost:3000 and talks to the backend on port 8080.

## Running the iPhone app

Requires a Mac with Xcode, Node.js, and CocoaPods.

```bash
cd mobile-app
npm install
cd ios
pod install
open SauceRobotMobile.xcworkspace
```

In Xcode, choose your own team under Signing & Capabilities, then build and run
on a simulator or a phone.

## License

MIT. See [LICENSE](LICENSE).
