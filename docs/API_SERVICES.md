# API & Services

This document details every service in the app, the Laravel backend API, and how data flows between them.

---

## Laravel Backend API

### Base URL Configuration

The app uses environment-aware base URLs configured in `ApiService`:

| Platform         | Base URL                    |
| ---------------- | --------------------------- |
| Web (debug)      | `http://localhost:8000/api` |
| Android Emulator | `http://10.0.2.2:8000/api`  |
| Physical Device  | Configured ngrok tunnel URL |
| Production       | Production server URL       |

### API Endpoints

#### Routes

| Method | Endpoint       | Description              | Used By      |
| ------ | -------------- | ------------------------ | ------------ |
| GET    | `/routes`      | Fetch all jeepney routes | `ApiService` |
| GET    | `/routes/{id}` | Fetch route by ID        | `ApiService` |

#### Landmarks

| Method | Endpoint                              | Description              | Used By      |
| ------ | ------------------------------------- | ------------------------ | ------------ |
| GET    | `/landmarks`                          | Fetch all landmarks      | `ApiService` |
| GET    | `/landmarks/featured`                 | Fetch featured landmarks | `ApiService` |
| GET    | `/landmarks?category={cat}`           | Filter by category       | `ApiService` |
| GET    | `/landmarks/nearby?lat=&lng=&radius=` | Nearby landmarks         | `ApiService` |
| GET    | `/landmarks/{id}`                     | Fetch landmark by ID     | `ApiService` |

#### Authentication

| Method | Endpoint    | Description              | Used By       |
| ------ | ----------- | ------------------------ | ------------- |
| POST   | `/register` | Register new user        | `AuthService` |
| POST   | `/login`    | Login, receive token     | `AuthService` |
| POST   | `/logout`   | Logout, revoke token     | `AuthService` |
| GET    | `/user`     | Get current user profile | `AuthService` |

#### Fare Settings

| Method | Endpoint          | Description           | Used By               |
| ------ | ----------------- | --------------------- | --------------------- |
| GET    | `/fare-settings`  | Get admin fare rates  | `FareSettingsService` |
| POST   | `/calculate-fare` | Server-side fare calc | `ApiService`          |

#### Recent Activities

| Method | Endpoint                        | Description           | Used By                    |
| ------ | ------------------------------- | --------------------- | -------------------------- |
| GET    | `/recent-activities`            | Get user's activities | `RecentActivityApiService` |
| POST   | `/recent-activities`            | Create activity       | `RecentActivityApiService` |
| POST   | `/recent-activities/batch-sync` | Batch sync activities | `RecentActivityApiService` |
| DELETE | `/recent-activities/{id}`       | Delete activity       | `RecentActivityApiService` |
| DELETE | `/recent-activities`            | Clear all activities  | `RecentActivityApiService` |

#### Support Tickets

| Method | Endpoint                          | Description           | Used By          |
| ------ | --------------------------------- | --------------------- | ---------------- |
| POST   | `/support-tickets`                | Create ticket         | `SupportService` |
| GET    | `/support-tickets`                | List user's tickets   | `SupportService` |
| GET    | `/support-tickets/{id}`           | Get ticket details    | `SupportService` |
| POST   | `/support-tickets/{id}/follow-up` | Add follow-up message | `SupportService` |
| POST   | `/support-tickets/{id}/cancel`    | Cancel ticket         | `SupportService` |

#### Notifications

| Method | Endpoint                       | Description         | Used By          |
| ------ | ------------------------------ | ------------------- | ---------------- |
| GET    | `/notifications`               | Get notifications   | `SupportService` |
| GET    | `/notifications/unread-count`  | Get unread count    | `SupportService` |
| POST   | `/notifications/{id}/read`     | Mark as read        | `SupportService` |
| POST   | `/notifications/mark-all-read` | Mark all as read    | `SupportService` |
| DELETE | `/notifications/{id}`          | Delete notification | `SupportService` |

### External APIs

| API              | Purpose                    | Used By               |
| ---------------- | -------------------------- | --------------------- |
| OSRM             | Walking/driving directions | `WalkingRouteService` |
| OpenRouteService | Walking directions         | `WalkingRouteService` |
| Nominatim (OSM)  | Geocoding / place search   | `LocationService`     |
| OpenStreetMap    | Map tiles                  | `flutter_map` widgets |

---

## Service Catalog

### 1. `ApiService` — Central HTTP Client

**File:** `lib/services/api_service.dart`
**Pattern:** Singleton

The single point of contact for all Laravel API calls. Handles:

- Environment-aware base URL selection
- JSON parsing and error handling
- `ApiException` for HTTP errors

**Key methods:**

- `fetchAllRoutes()` → `List<JeepneyRoute>`
- `fetchAllLandmarks()` → `List<Landmark>`
- `fetchFeaturedLandmarks()` → `List<Landmark>`
- `fetchLandmarksByCategory(category)` → `List<Landmark>`
- `fetchNearbyLandmarks(lat, lng, radius)` → `List<Landmark>`
- `fetchLandmarkById(id)` → `Landmark`
- `fetchRouteById(id)` → `JeepneyRoute`
- `calculateFare(distance)` → `Map` (server-side fare calculation)

---

### 2. `AuthService` — Authentication

**File:** `lib/services/auth_service.dart`
**Pattern:** Singleton

Manages the full auth lifecycle with Laravel Sanctum.

**Security features:**

- Input sanitization via `SecurityUtils`
- Rate limiting (5 attempts / 15 minutes)
- Token stored in `FlutterSecureStorage` with 7-day expiry
- User data cached locally for offline access

**Key methods:**

- `register(name, email, phone, password, confirm)` → token
- `login(email, password)` → token
- `logout()` → revoke token
- `getCurrentUser()` → `UserModel`
- `isLoggedIn()` → bool (checks token validity)
- `getToken()` → String?
- `getCachedUser()` → `UserModel?`

---

### 3. `AppDataPreloader` — Splash Screen Loader

**File:** `lib/services/app_data_preloader.dart`
**Pattern:** Singleton

Pre-loads all critical data during splash screen for instant navigation.

**What it loads (in parallel):**

1. All jeepney routes → cached in `RouteRepository`
2. All landmarks as `Map<int, Landmark>` → cached locally
3. Auth status → checked via `AuthRepository`
4. Fare settings → loaded via `FareSettingsService`
5. Transit graph → built in background (non-blocking)

**Key properties:**

- `cachedRoutes` → `List<JeepneyRoute>`
- `cachedLandmarkMaps` → `Map<int, Landmark>`
- `hybridRouter` → `HybridTransitRouter`
- `isInitialized` → bool

**Key methods:**

- `initialize(routeRepo, landmarkRepo, authRepo)` → loads everything
- `preInitialize()` → builds `HybridTransitRouter` in background
- `ensureGraphReady()` → waits for graph build (called before route calc)

**Performance:**

- 8-second timeout on API calls
- Graph build runs on a separate isolate (via `compute`)
- Non-blocking — splash navigates immediately after API data loads

---

### 4. `RouteCalculationService` — Route Finder

**File:** `lib/services/route_calculation_service.dart`
**Pattern:** Static methods

Orchestrates route calculation by combining multiple algorithms.

**Key method:**

```
calculateRoute(origin, destination) → RouteCalculationResult
  ├── HybridTransitRouter.findRoutes()     → hybrid suggestions
  ├── RouteMatcher.matchRoutes()            → legacy direct matches
  └── MultiTransferMatcher.findRoutes()     → legacy multi-transfers
```

**Returns:** `RouteCalculationResult` with:

- `hybridSuggestedRoutes` — from graph pathfinder
- `legacyMatches` — from OSRM path matching
- `legacyMultiTransfer` — from legacy transfer finder

---

### 5. `WalkingRouteService` — Walking Directions

**File:** `lib/services/walking_route_service.dart`
**Pattern:** Static methods

Fetches pedestrian walking polylines between two coordinates.

**API priority:**

1. **OpenRouteService** (primary) — free tier, requires API key
2. **OSRM foot profile** (fallback) — self-hosted or public, no key needed
3. **Straight line** (final fallback) — if both APIs fail

**Caching:** LRU cache with 50 entries to avoid redundant API calls.

**Key methods:**

- `fetchWalkingPath(from, to)` → `List<LatLng>`
- `fetchWalkingPathsBatch(pairs)` → `Map<String, List<LatLng>>`
- `clearCache()`

---

### 6. `FareSettingsService` — Fare Rates

**File:** `lib/services/fare_settings_service.dart`
**Pattern:** Singleton, ChangeNotifier

Manages admin-configurable fare rates fetched from the API.

**Default values (if API unavailable):**
| Setting | Default |
|-------------------|-----------|
| Base fare | ₱13.00 |
| Fare per km | ₱1.80 |
| Base fare distance| 4.0 km |

**Key methods:**

- `initialize()` — fetch rates from API, cache in SharedPreferences
- `calculateFare(distanceKm)` → `double`
- `calculateFareWithDiscount(distanceKm, discountType)` → `double` (20% off)

---

### 7. `SettingsService` — User Preferences

**File:** `lib/services/settings_service.dart`
**Pattern:** Singleton, ChangeNotifier

Persists user preferences in `SharedPreferences`.

**Settings:**
| Key | Type | Default |
|----------------------|--------|----------|
| `notifications` | bool | true |
| `sound` | bool | true |
| `vibration` | bool | true |
| `language` | String | "en" |
| `useMiles` | bool | false |
| `locationEnabled` | bool | true |
| `tutorialComplete` | bool | false |

**Key methods:**

- `formatDistance(distanceKm)` → "2.5 km" or "1.6 mi"
- `triggerVibration()` — haptic feedback if enabled
- `clearCache()` — reset all settings

---

### 8. `LocationService` — GPS & Geocoding

**File:** `lib/services/location_service.dart`
**Pattern:** Singleton, ChangeNotifier

Centralized location operations.

**Key methods:**

- `getCurrentLocation()` → `LocationResult` (lat/lng + address)
- `getCurrentPosition()` → `Position` (raw GPS)
- `reverseGeocode(lat, lng)` → `GeocodingResult` (address from coords)
- `searchPlaces(query)` → `List<PlaceSearchResult>` (Nominatim)

**Default fallback:** Davao City center (7.0731, 125.6128)

---

### 9. `RecentActivityServiceV2` — Activity Tracking

**File:** `lib/services/recent_activity_service_v2.dart`
**Pattern:** Static facade

Unified entry point for tracking all user activities. Delegates to `ActivitySyncManager`.

**Key methods:**

- `addRouteCalculation(userId, from, to, routes, fare)`
- `addFareCalculation(userId, from, to, distance, fare)`
- `addLocationSearch(userId, query, result)`
- `addRouteSaved(userId, routeName)`
- `addTicketCreated(userId, subject, type)`
- `addTicketReplied(userId, subject)`
- `addTicketStatusChanged(userId, subject, status)`
- `getActivities(userId)` → `List<RecentActivityModel>`
- `sync(userId)` — manual sync trigger
- `clearAll(userId)` — clear all activities

---

### 10. `ActivitySyncManager` — Offline Sync

**File:** `lib/services/activity_sync_manager.dart`
**Pattern:** Singleton

Manages bidirectional sync between SQLite and the Laravel API.

**Sync triggers:**

- App start (`fullSync`)
- 5+ unsynced items (`threshold sync`)
- Every 30 minutes (`timer sync`)
- Manual pull-to-refresh

**Strategy:**

- `track(activity)` → insert into SQLite
- `syncToServer()` → batch upload unsynced, fallback to individual
- `pullFromServer()` → merge server activities into local DB
- `fullSync()` → pull + push

**Connectivity-aware:** Skips sync when offline (via `connectivity_plus`).

---

### 11. `SupportService` — Ticket API Client

**File:** `lib/services/support_service.dart`
**Pattern:** Static methods

REST API client for the support ticket system.

**Key methods:**

- `createTicket(type, priority, subject, description)` → `CreateTicketResult`
- `getTickets(status?, page?)` → `TicketListResult`
- `getTicketDetails(id)` → `TicketDetailResult`
- `addFollowUpMessage(id, message)` → `FollowUpResult`
- `cancelTicket(id)` → `SimpleResult`
- `getNotifications()` → `NotificationListResult`
- `getUnreadCount()` → `UnreadCountResult`
- `markNotificationAsRead(id)`, `markAllNotificationsAsRead()`, `deleteNotification(id)`

---

### 12. `TicketNotificationService` — Background Polling

**File:** `lib/services/ticket_notification_service.dart`
**Pattern:** Singleton

Polls the server every 60 seconds for new ticket notifications.

**Key features:**

- Background timer (60-second interval)
- Listener pattern for UI updates
- Unread count badge for profile screen
- Auto-starts in `main()`

---

### 13. `LocalizationService` — Translations

**File:** `lib/services/localization_service.dart`
**Pattern:** Static methods

Static translation engine for 3 languages.

**Usage:**

```dart
// In any widget:
Text(context.tr('welcome'))  // "Welcome" / "Maligayang pagdating" / "Maayong pag-abot"
```

**Supported languages:** English (`en`), Filipino (`fil`), Cebuano (`ceb`)
**Translation keys:** ~50+ covering all screens and features

---

## Data Flow Diagrams

### Authentication Flow

```
LoginScreen → AuthRepository.login()
  → AuthService.login(email, password)
    → POST /api/login
    → Store token in FlutterSecureStorage
    → Cache user data
    → AuthState.authenticated
  → Navigate to MainNavigation
```

### Route Search Flow

```
SearchScreen → AppSearchController.calculateRoute()
  → RouteCalculationService.calculateRoute(origin, dest)
    → AppDataPreloader.ensureGraphReady()
    → HybridTransitRouter.findRoutes() → SuggestedRoutes
    → RouteMatcher.matchRoutes() → RouteMatchResults
    → MultiTransferMatcher.findRoutes() → MultiTransferRoutes
  → Display results in RouteListPanel / SuggestedRoutesModal
```

### Activity Sync Flow

```
User action → RecentActivityServiceV2.addXxx()
  → ActivitySyncManager.track(activity)
    → ActivityDatabase.insertActivity() (SQLite)
    → If online + threshold:
        → RecentActivityApiService.batchSync()
          → POST /api/recent-activities/batch-sync
```
