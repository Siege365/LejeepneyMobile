# Setup & Deployment

This document explains how to set up the LeJeepney project locally and build it for deployment.

---

## Prerequisites

### Required Software

| Software       | Version | Purpose                         |
| -------------- | ------- | ------------------------------- |
| Flutter SDK    | 3.10.7+ | Framework                       |
| Dart SDK       | 3.10.7+ | Language (bundled with Flutter) |
| Android Studio | Latest  | Android build tools + emulator  |
| VS Code        | Latest  | Recommended IDE                 |
| Git            | Latest  | Version control                 |

### Optional (for full stack development)

| Software | Version | Purpose                            |
| -------- | ------- | ---------------------------------- |
| PHP      | 8.1+    | Laravel backend                    |
| Composer | Latest  | PHP dependency manager             |
| MySQL    | 8.0+    | Backend database                   |
| Node.js  | 18+     | Laravel frontend assets            |
| ngrok    | Latest  | Tunnel for physical device testing |

---

## Getting Started

### 1. Clone the Repository

```bash
git clone <repository-url>
cd final_project_cce106
```

### 2. Install Flutter Dependencies

```bash
flutter pub get
```

### 3. Verify Flutter Setup

```bash
flutter doctor
```

Ensure all checkmarks are green for your target platform (Android/iOS/Web).

### 4. Configure the Backend URL

Edit `lib/services/api_service.dart` and update the base URL:

```dart
// For Android emulator:
static const String _baseUrl = 'http://10.0.2.2:8000/api';

// For physical device (use ngrok):
static const String _baseUrl = 'https://your-tunnel.ngrok-free.app/api';

// For web:
static const String _baseUrl = 'http://localhost:8000/api';
```

### 5. Run the App

```bash
# Android emulator
flutter run

# Web
flutter run -d chrome

# Specific device
flutter devices          # List available devices
flutter run -d <device>
```

---

## Project Dependencies

### Production Dependencies

| Package                  | Version  | Purpose                             |
| ------------------------ | -------- | ----------------------------------- |
| `flutter_map`            | ^6.1.0   | OpenStreetMap map widget            |
| `latlong2`               | ^0.9.0   | Geographic coordinate types         |
| `geolocator`             | ^11.0.0  | GPS location access                 |
| `http`                   | ^1.1.0   | HTTP client for API calls           |
| `shared_preferences`     | ^2.2.2   | Simple key-value local storage      |
| `flutter_secure_storage` | ^9.0.0   | Encrypted storage for tokens        |
| `provider`               | ^6.1.5+1 | State management                    |
| `url_launcher`           | ^6.2.3   | Open URLs in browser                |
| `intl`                   | ^0.19.0  | Date/number formatting              |
| `sqflite`                | ^2.3.0   | SQLite database for offline storage |
| `path`                   | ^1.8.3   | File path utilities                 |
| `connectivity_plus`      | ^5.0.2   | Network connectivity detection      |
| `flutter_svg`            | ^2.2.3   | SVG image rendering                 |
| `google_fonts`           | ^6.2.1   | Google Fonts integration            |
| `cupertino_icons`        | ^1.0.8   | iOS-style icons                     |

### Dev Dependencies

| Package         | Version | Purpose        |
| --------------- | ------- | -------------- |
| `flutter_test`  | SDK     | Widget testing |
| `flutter_lints` | ^6.0.0  | Lint rules     |

---

## Assets

### Directory Structure

```
assets/
├── fonts/          # Custom fonts (if any)
├── icons/          # App icons
└── images/         # Images including LeJeepneyFinal.png (app logo)
```

### Registered in pubspec.yaml

```yaml
flutter:
  assets:
    - assets/images/
    - assets/icons/
```

---

## Building for Release

### Android APK

```bash
# Debug APK
flutter build apk --debug

# Release APK
flutter build apk --release

# Output: build/app/outputs/flutter-apk/app-release.apk
```

### Android App Bundle (for Play Store)

```bash
flutter build appbundle --release

# Output: build/app/outputs/bundle/release/app-release.aab
```

### Web

```bash
flutter build web --release

# Output: build/web/
```

### iOS (macOS only)

```bash
flutter build ios --release
```

---

## Backend Setup (Laravel)

The app requires a Laravel backend API. Key setup steps:

### 1. Install Laravel

```bash
cd backend/   # (separate repository)
composer install
cp .env.example .env
php artisan key:generate
```

### 2. Configure Database

Edit `.env`:

```
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=lejeepney
DB_USERNAME=root
DB_PASSWORD=your_password
```

### 3. Run Migrations

```bash
php artisan migrate
php artisan db:seed   # Seed routes, landmarks, fare settings
```

### 4. Start the Server

```bash
php artisan serve     # http://localhost:8000
```

### 5. For Physical Device Testing

```bash
ngrok http 8000       # Creates a public tunnel URL
```

Update the `_baseUrl` in `api_service.dart` with the ngrok URL.

---

## Environment Configuration

### Android Permissions

Already configured in `AndroidManifest.xml`:

- `ACCESS_FINE_LOCATION` — GPS access
- `ACCESS_COARSE_LOCATION` — Network-based location
- `INTERNET` — API calls

### iOS Permissions

Already configured in `Info.plist`:

- `NSLocationWhenInUseUsageDescription`
- `NSLocationAlwaysUsageDescription`

### API Keys

| Service             | Required? | Configuration Location          |
| ------------------- | --------- | ------------------------------- |
| OpenStreetMap Tiles | No        | Free, no key needed             |
| OSRM                | No        | Public instance, no key         |
| OpenRouteService    | Optional  | In `walking_route_service.dart` |
| Nominatim           | No        | Free with rate limiting         |

---

## Troubleshooting

### Common Issues

**1. "Connection refused" on API calls**

- Ensure Laravel server is running (`php artisan serve`)
- Check base URL matches your platform (emulator vs physical device)
- For physical device: use ngrok tunnel

**2. Map tiles not loading**

- Check internet connectivity
- OpenStreetMap tile servers may have rate limits
- The `ResilientTileProvider` handles retries automatically

**3. GPS location not working**

- Ensure location permissions are granted
- Enable location services on device
- Check `SettingsService.locationEnabled` is true
- Fallback: defaults to Davao City center (7.0731, 125.6128)

**4. Splash screen takes too long**

- API calls have 8-second timeout
- Transit graph builds in background (non-blocking)
- If backend is slow/down, app will use cached data

**5. Build fails after updating dependencies**

```bash
flutter clean
flutter pub get
flutter run
```

**6. Android Gradle build issues**

```bash
cd android
./gradlew clean
cd ..
flutter run
```

---

## Procfile (Deployment)

The project includes a `Procfile` for deployment platforms like Heroku/Railway:

```
web: <command>
```

This is for deploying the web version of the Flutter app.
