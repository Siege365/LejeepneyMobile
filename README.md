# LeJeepney 🚐

A Flutter-based jeepney navigation app for **Davao City, Philippines**. LeJeepney helps commuters find the best jeepney routes, calculate fares, and explore city landmarks — all without needing Google Maps.

## Features

- 🗺️ **Route Search** — Find the best jeepney route between any two points (direct, 1-transfer, or 2-transfer)
- 💰 **Fare Calculator** — Calculate exact fares with student/senior discounts
- 📍 **Landmarks Directory** — Browse Davao City landmarks by category
- 🚶 **Walking Directions** — See walking paths to and from jeepney stops
- 🌐 **Multi-Language** — English, Filipino, and Cebuano
- 📊 **Activity Tracking** — Offline-first with server sync
- 🎫 **Support Tickets** — Submit and track support requests
- ⚙️ **Settings** — Distance units (km/miles), language, notifications

## Tech Stack

| Layer    | Technology                           |
| -------- | ------------------------------------ |
| Frontend | Flutter (Dart) with Material 3       |
| Maps     | flutter_map + OpenStreetMap          |
| Routing  | OSRM + custom graph-based pathfinder |
| Backend  | Laravel (PHP) REST API               |
| Auth     | Laravel Sanctum (token-based)        |
| State    | Provider                             |
| Local DB | SQLite (offline activity storage)    |

## Getting Started

### Prerequisites

- Flutter SDK 3.10.7+
- Android Studio (for Android builds)
- A running Laravel backend instance

### Installation

```bash
# Clone the repository
git clone <repository-url>
cd final_project_cce106

# Install dependencies
flutter pub get

# Run the app
flutter run
```

### Backend Configuration

Update the API base URL in `lib/services/api_service.dart` to match your Laravel server:

- **Android Emulator:** `http://10.0.2.2:8000/api`
- **Physical Device:** Use an ngrok tunnel URL
- **Web:** `http://localhost:8000/api`

## Documentation

Detailed documentation is available in the [`docs/`](docs/) folder:

| Document                                    | Description                                  |
| ------------------------------------------- | -------------------------------------------- |
| [OVERVIEW.md](docs/OVERVIEW.md)             | App purpose, tech stack, and project status  |
| [ARCHITECTURE.md](docs/ARCHITECTURE.md)     | Folder structure, design patterns, data flow |
| [FEATURES.md](docs/FEATURES.md)             | All features explained in detail             |
| [API_SERVICES.md](docs/API_SERVICES.md)     | Laravel API endpoints and service catalog    |
| [ROUTING_SYSTEM.md](docs/ROUTING_SYSTEM.md) | Transit routing engine deep dive             |
| [SETUP.md](docs/SETUP.md)                   | Setup, build, and deployment guide           |

## Project Structure

```
lib/
├── main.dart              # App entry point
├── constants/             # Colors, strings, routes, theme
├── controllers/           # UI state (FareCalculator, Search)
├── database/              # SQLite for offline activity storage
├── models/                # Data models (Route, Landmark, User, etc.)
├── providers/             # Provider configuration
├── repositories/          # Data access layer with caching
├── screens/               # All UI screens
├── services/              # Business logic and API clients
├── utils/                 # Utilities + transit routing engine
└── widgets/               # Reusable UI components
```

## License

This project is developed as a final project for CCE106.
