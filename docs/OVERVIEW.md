# LeJeepney — App Overview

## What is LeJeepney?

**LeJeepney** is a Flutter-based mobile navigation app designed to help commuters in **Davao City, Philippines** find the best jeepney routes for their journeys. It serves as a transit companion — think Google Maps, but purpose-built for the Philippine jeepney system.

## Problem It Solves

Navigating Davao City's jeepney network is challenging for newcomers and even locals:

- **No official route maps** — jeepney routes are passed down by word of mouth.
- **Confusing transfers** — getting from point A to B often requires 1–2 jeepney transfers.
- **Unclear fares** — passengers don't always know the correct fare for their distance.
- **No digital tools** — there is no widely-used app for jeepney route planning in Davao.

LeJeepney solves all of these by providing:

1. **Route search** — Enter your origin and destination, and the app suggests the best jeepney routes.
2. **Fare calculator** — See the exact fare based on distance, with student/senior discounts.
3. **Landmark directory** — Browse and search Davao City landmarks as navigation reference points.
4. **Walking directions** — See walking paths to/from jeepney stops.
5. **Multi-language support** — English, Filipino, and Cebuano.

---

## Tech Stack

| Layer            | Technology                                                     |
| ---------------- | -------------------------------------------------------------- |
| **Frontend**     | Flutter (Dart) with Material 3                                 |
| **Maps**         | flutter_map + OpenStreetMap tiles (not Google Maps)            |
| **Routing APIs** | OSRM (walking/driving directions), OpenRouteService (fallback) |
| **Backend**      | Laravel (PHP) REST API                                         |
| **Database**     | SQLite (local offline storage), Laravel MySQL (server)         |
| **Auth**         | Laravel Sanctum (token-based)                                  |
| **State Mgmt**   | Provider                                                       |
| **Storage**      | SharedPreferences, FlutterSecureStorage                        |

### Why OpenStreetMap instead of Google Maps?

Google Maps billing is not well supported in the Philippines, and free tier limits are restrictive. OpenStreetMap with flutter_map provides:

- **Free unlimited map tiles**
- **No API key required** for basic tiles
- **OSRM** for free routing (self-hostable)
- Better coverage of jeepney-relevant roads in Davao City

---

## Target Users

- **Daily commuters** in Davao City who ride jeepneys
- **Students** navigating to schools/universities
- **Tourists/newcomers** unfamiliar with the jeepney system
- **Senior citizens** who benefit from fare discount calculations

---

## Key Screens

| Screen               | Purpose                                              |
| -------------------- | ---------------------------------------------------- |
| **Splash**           | Pre-loads data (routes, landmarks, auth)             |
| **Login / Register** | Authentication via Laravel Sanctum                   |
| **Home**             | Welcome dashboard with recent activities             |
| **Search**           | Route finder — enter origin/destination, get results |
| **Fare Calculator**  | Tap two map points to calculate distance and fare    |
| **Landmarks**        | Browse/search Davao City landmarks by category       |
| **Profile**          | Settings, about, support tickets, recent activity    |

---

## App Architecture Summary

```
┌─────────────────────────────────────────────────┐
│                   UI Layer                       │
│  Screens → Widgets → Controllers (ChangeNotifier)│
├─────────────────────────────────────────────────┤
│               State Management                   │
│  Provider → Repositories → Services              │
├─────────────────────────────────────────────────┤
│                Data Layer                        │
│  ApiService (HTTP) │ SQLite │ SecureStorage       │
├─────────────────────────────────────────────────┤
│             External APIs                        │
│  Laravel Backend │ OSRM │ OpenRouteService        │
│  OpenStreetMap   │ Nominatim (geocoding)          │
└─────────────────────────────────────────────────┘
```

---

## Project Status

- ✅ Route search with hybrid routing engine
- ✅ Fare calculation with admin-configurable rates
- ✅ Multi-transfer route suggestions (up to 2 transfers)
- ✅ Walking directions to/from jeepney stops
- ✅ Landmark directory with categories and search
- ✅ Support ticket system with notifications
- ✅ Offline activity tracking with server sync
- ✅ Multi-language support (EN/FIL/CEB)
- ✅ Distance unit conversion (km/miles)
- ✅ Data pre-loading for fast app startup
