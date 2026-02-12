# Architecture

## Project Structure

```
lib/
├── main.dart                          # App entry point
├── constants/                         # App-wide constants and theme
│   ├── app_colors.dart                #   Color palette (primary: #EBAF3E golden)
│   ├── app_dimensions.dart            #   Spacing and sizing constants
│   ├── app_routes.dart                #   Route names + AppRouter + NavigationService
│   ├── app_strings.dart               #   All hardcoded English text strings
│   ├── app_theme.dart                 #   Material 3 theme configuration
│   ├── constants.dart                 #   Barrel file for all constants
│   └── map_constants.dart             #   Map center (Davao), zoom levels, tile URLs
├── controllers/                       # UI state controllers (ChangeNotifier)
│   ├── controllers.dart               #   Barrel file
│   ├── fare_calculator_controller.dart #  Fare calculator state management
│   └── search_controller.dart         #   Search/route finding state management
├── database/                          # Local SQLite database
│   ├── activity_database.dart         #   Recent activity CRUD operations
│   └── database_helper.dart           #   DB initialization helper
├── models/                            # Data models
│   ├── jeepney_route.dart             #   JeepneyRoute + Waypoint models
│   ├── landmark.dart                  #   Landmark + LandmarkCategory models
│   ├── models.dart                    #   Barrel file
│   ├── recent_activity_model.dart     #   RecentActivityModel (SQLite + API)
│   ├── support_ticket.dart            #   SupportTicket, TicketReply, enums
│   └── user_model.dart                #   UserModel for auth
├── providers/                         # Provider configuration
│   └── app_providers.dart             #   AppProviderScope + all providers
├── repositories/                      # Data access layer (Repository pattern)
│   ├── auth_repository.dart           #   Auth state management
│   ├── base_repository.dart           #   Abstract base with caching + Result<T>
│   ├── landmark_repository.dart       #   Landmark data access
│   ├── repositories.dart              #   Barrel file
│   └── route_repository.dart          #   Jeepney route data access
├── screens/                           # UI screens
│   ├── splash_screen.dart             #   Boot screen — pre-loads all data
│   ├── main_navigation.dart           #   Bottom nav with 5 tabs
│   ├── auth/                          #   Login + Registration screens
│   ├── fare/                          #   Fare calculator + map screen
│   ├── home/                          #   Home dashboard
│   ├── landmarks/                     #   Landmark directory
│   ├── profile/                       #   Settings, about, activity, support
│   ├── search/                        #   Route search screen
│   └── support/                       #   Support ticket screens
├── services/                          # Business logic services
│   ├── activity_sync_manager.dart     #   Local ↔ server activity sync
│   ├── api_service.dart               #   Central HTTP client (Laravel)
│   ├── app_data_preloader.dart        #   Splash screen data pre-loading
│   ├── auth_service.dart              #   Laravel Sanctum auth
│   ├── fare_settings_service.dart     #   Admin-configurable fare rates
│   ├── localization_service.dart      #   Multi-language translations
│   ├── location_service.dart          #   GPS + geocoding + place search
│   ├── recent_activity_api_service.dart #  Activity REST API client
│   ├── recent_activity_service_v2.dart  #  Activity tracking facade
│   ├── route_calculation_service.dart #   Main route calculation orchestrator
│   ├── services.dart                  #   Barrel file
│   ├── settings_service.dart          #   User preferences (ChangeNotifier)
│   ├── support_service.dart           #   Support ticket API client
│   ├── ticket_notification_service.dart # Background ticket notification polling
│   └── walking_route_service.dart     #   OSRM/ORS walking path fetcher
├── utils/                             # Utility functions
│   ├── multi_transfer_matcher.dart    #   Legacy multi-transfer route finder
│   ├── page_transitions.dart          #   Custom page transition animations
│   ├── resilient_tile_provider.dart   #   Fault-tolerant map tile loading
│   ├── route_display_helpers.dart     #   Route formatting utilities
│   ├── route_matcher.dart             #   Legacy route-to-path matching
│   ├── security_utils.dart            #   Input sanitization + validation
│   ├── ticket_label_selector.dart     #   Ticket type label picker UI
│   └── transit_routing/               #   Core routing engine (see below)
│       ├── geo_utils.dart             #     Haversine, bearing, path operations
│       ├── hybrid_router.dart         #     Main hybrid routing orchestrator
│       ├── jeepney_pathfinder.dart    #     Graph-based pathfinding (Dijkstra-like)
│       ├── models.dart                #     TransitNode, TransitEdge, SuggestedRoute
│       ├── route_validator.dart       #     OSRM ↔ jeepney route coverage validation
│       ├── transit_graph.dart         #     Jeepney network graph builder
│       └── transit_routing.dart       #     Barrel file
└── widgets/                           # Reusable UI components
    ├── common/                        #   Shared widgets
    │   ├── common_widgets.dart        #     Section headers, cards, etc.
    │   └── tutorial_overlay.dart      #     First-time user tutorial
    ├── map/                           #   Map-related widgets
    │   ├── app_map.dart               #     Main map widget wrapper
    │   ├── map_markers.dart           #     Custom map marker builders
    │   └── map_widgets.dart           #     Barrel file
    ├── route/                         #   Route display widgets
    │   ├── direct_route_card.dart     #     Single-route result card
    │   ├── multi_transfer_route_card.dart # Multi-transfer route card
    │   ├── route_display_widgets.dart #     Route info formatting
    │   ├── route_widgets.dart         #     Barrel file
    │   ├── routes_list_panel.dart     #     Scrollable route results list
    │   └── suggested_routes_modal.dart #    Bottom sheet for route details
    ├── route_list_item.dart           #   Individual route list row
    ├── travel_history_item.dart       #   Recent activity list row
    └── widgets.dart                   #   Barrel file
```

---

## Design Patterns

### 1. Provider State Management

The app uses the **Provider** package for dependency injection and reactive state management.

**Setup in `AppProviderScope`:**

```
MultiProvider
├── ChangeNotifierProvider<SettingsService>      (singleton)
├── ChangeNotifierProvider<LocationService>      (singleton)
├── ChangeNotifierProvider<AuthRepository>       (BaseRepository)
├── ChangeNotifierProvider<RouteRepository>      (BaseRepository)
├── ChangeNotifierProvider<LandmarkRepository>   (BaseRepository)
└── ChangeNotifierProvider<FareCalculatorController> (ChangeNotifier)
```

Screens access state via:

- `context.read<T>()` — one-time read (in callbacks)
- `context.watch<T>()` — reactive rebuild on change (in build methods)

### 2. Repository Pattern

All API data access goes through repositories that extend `BaseRepository`:

```
BaseRepository (abstract, ChangeNotifier)
├── Result<T> — success/failure wrapper for all operations
├── CacheEntry<T> — value + timestamp, 5-min default expiry
├── isLoading, error — shared state
│
├── AuthRepository
│   └── AuthState enum (initial/loading/authenticated/unauthenticated/error)
│
├── RouteRepository
│   └── Caches: allRoutes, routeById, search results
│
└── LandmarkRepository
    └── Caches: allLandmarks, featured, byCategory, nearby, byId
```

**Benefits:**

- Automatic caching with TTL
- Consistent error handling via `Result<T>`
- Loading state management
- ChangeNotifier integration for UI reactivity

### 3. Singleton Services

Cross-cutting services use the singleton pattern:

| Service                     | Pattern   | Purpose                           |
| --------------------------- | --------- | --------------------------------- |
| `ApiService`                | Singleton | HTTP client                       |
| `AuthService`               | Singleton | Token management + auth API       |
| `SettingsService`           | Singleton | User preferences (ChangeNotifier) |
| `LocationService`           | Singleton | GPS + geocoding (ChangeNotifier)  |
| `FareSettingsService`       | Singleton | Fare rates (ChangeNotifier)       |
| `AppDataPreloader`          | Singleton | Splash screen data loading        |
| `ActivitySyncManager`       | Singleton | Offline ↔ server sync             |
| `TicketNotificationService` | Singleton | Background notification polling   |

### 4. Barrel Files

Every folder has a barrel file (e.g., `models.dart`, `services.dart`, `widgets.dart`) that re-exports its contents for cleaner imports. However, most screens import files directly rather than through barrel files.

---

## Navigation Architecture

### Route Configuration

Routes are defined in `AppRoutes` (constants) and generated by `AppRouter.onGenerateRoute`:

```
/splash           → SplashScreen
/login             → LoginScreen
/signIn            → SignInScreen
/main              → MainNavigation
/fareCalculator    → FareCalculatorScreen
/mapFareCalculator → MapFareCalculatorScreen
/landmarks         → LandmarksScreen
/settings          → SettingsScreen
/about             → AboutScreen
/createTicket      → CreateTicketScreen
/tickets           → TicketListScreen
/ticketDetail      → TicketDetailScreen
```

### Navigation Flow

```
App Start
  └─→ SplashScreen (pre-load data)
        ├─→ LoginScreen (not authenticated)
        │     ├─→ SignInScreen (register)
        │     └─→ MainNavigation (on login success)
        └─→ MainNavigation (already authenticated)
              ├── Tab 0: HomeScreen
              ├── Tab 1: SearchScreen
              ├── Tab 2: FareCalculatorScreen (center FAB)
              ├── Tab 3: LandmarksScreen
              └── Tab 4: ProfileScreen
                    ├─→ SettingsScreen
                    ├─→ AboutScreen
                    ├─→ RecentActivityScreen
                    ├─→ AccountSettingsScreen
                    ├─→ NotificationsScreen
                    ├─→ ReportFeedbackScreen
                    └─→ TicketListScreen
                          ├─→ CreateTicketScreen
                          └─→ TicketDetailScreen
```

### NavigationService

A `NavigationService` singleton with a `GlobalKey<NavigatorState>` enables navigation from non-widget code (services, controllers):

```dart
NavigationService.instance.navigateTo('/main');
```

---

## Data Flow

### App Boot Sequence

```
1. main() → Initialize background services
     ├── RecentActivityServiceV2.initialize()
     ├── TicketNotificationService.initialize()
     └── FareSettingsService.initialize()

2. MyApp → AppProviderScope wraps widget tree with all providers

3. SplashScreen._initializeAndNavigate():
     ├── AppDataPreloader.initialize(routeRepo, landmarkRepo, authRepo)
     │     ├── Fetch all routes (API, 8s timeout)
     │     ├── Fetch all landmarks (API, 8s timeout)
     │     ├── Check auth status
     │     ├── Load fare settings
     │     └── Build transit graph (background, non-blocking)
     └── Navigate to MainNavigation or LoginScreen
```

### Route Calculation Flow

```
User enters origin + destination
  └─→ AppSearchController.calculateRoute()
        └─→ RouteCalculationService.calculateRoute()
              ├── await AppDataPreloader.ensureGraphReady()
              ├── HybridTransitRouter.findRoutes()     → hybrid suggestions
              ├── RouteMatcher.matchRoutes()            → legacy direct matches
              └── MultiTransferMatcher.findRoutes()     → legacy transfers
              └─→ RouteCalculationResult (combined)
```

### Activity Tracking Flow

```
User performs action (route calc, fare calc, etc.)
  └─→ RecentActivityServiceV2.addXxx()
        └─→ ActivitySyncManager.track()
              ├── Insert into SQLite (ActivityDatabase)
              └── If online + threshold reached:
                    └── syncToServer() → RecentActivityApiService
```

---

## Key Architectural Decisions

| Decision                       | Rationale                                                     |
| ------------------------------ | ------------------------------------------------------------- |
| OpenStreetMap over Google Maps | Google Maps billing not supported in Philippines              |
| OSRM for walking routes        | Free, self-hostable, no API key needed                        |
| Pre-load data at splash        | Eliminates loading spinners throughout the app                |
| Background graph build         | Transit graph is expensive; built async so splash is fast     |
| Hybrid routing engine          | Combines graph pathfinding with OSRM for best accuracy        |
| Legacy matchers as fallback    | Backward compatibility with original matching algorithms      |
| SQLite for activities          | Offline-first; syncs to server when connectivity is available |
| Provider over BLoC/Riverpod    | Simpler mental model; sufficient for this app's complexity    |
| Singleton services             | Shared state across screens without Provider boilerplate      |
| Result<T> pattern              | Type-safe error handling without try/catch everywhere         |
