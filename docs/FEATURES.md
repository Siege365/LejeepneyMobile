# Features

This document describes every user-facing feature in LeJeepney.

---

## 1. Authentication

### Files

- [screens/auth/login_screen.dart](../lib/screens/auth/login_screen.dart)
- [screens/auth/sign_in_screen.dart](../lib/screens/auth/sign_in_screen.dart)
- [services/auth_service.dart](../lib/services/auth_service.dart)
- [repositories/auth_repository.dart](../lib/repositories/auth_repository.dart)

### Description

Users can register and log in via **Laravel Sanctum** token-based authentication.

**Login:**

- Email + password
- Rate-limited: max 5 attempts per 15 minutes
- Token stored securely with 7-day expiry via `FlutterSecureStorage`
- Auto-login if valid token exists (checked during splash)

**Registration:**

- Name, email, phone, password
- Server-side validation with error messages displayed inline

**Security:**

- All inputs sanitized via `SecurityUtils` (XSS prevention, SQL injection prevention)
- Tokens encrypted at rest
- Password hashing handled server-side (Laravel)

**Guest Access:**

- Users can browse the app without logging in (limited features)
- Activities stored locally under a "guest" key

---

## 2. Home Dashboard

### Files

- [screens/home/home_screen.dart](../lib/screens/home/home_screen.dart)
- [widgets/travel_history_item.dart](../lib/widgets/travel_history_item.dart)
- [widgets/common/tutorial_overlay.dart](../lib/widgets/common/tutorial_overlay.dart)

### Description

The home screen welcomes the user and shows their recent activity.

**Features:**

- **Welcome header** — "Welcome to" (small) + "LeJeepney" (large bold) with help button
- **Recent activities list** — Shows last route calculations, fare lookups, ticket updates
- **Quick action buttons** — Navigate to Search, Fare Calculator, Landmarks
- **Tutorial overlay** — First-time users see an interactive tutorial explaining the app
- **Pull-to-refresh** — Refresh recent activities

---

## 3. Route Search

### Files

- [screens/search/search_screen.dart](../lib/screens/search/search_screen.dart)
- [controllers/search_controller.dart](../lib/controllers/search_controller.dart)
- [services/route_calculation_service.dart](../lib/services/route_calculation_service.dart)
- [widgets/route/suggested_routes_modal.dart](../lib/widgets/route/suggested_routes_modal.dart)
- [widgets/route/direct_route_card.dart](../lib/widgets/route/direct_route_card.dart)
- [widgets/route/multi_transfer_route_card.dart](../lib/widgets/route/multi_transfer_route_card.dart)
- [widgets/route/routes_list_panel.dart](../lib/widgets/route/routes_list_panel.dart)

### Description

The core feature — users find jeepney routes between two locations.

**How it works:**

1. **Enter origin** — Type a place name or use current GPS location
2. **Enter destination** — Search for a place via Nominatim geocoding
3. **Calculate route** — App finds the best jeepney routes

**Route types returned:**

- **Direct routes** — Single jeepney, no transfers needed
- **1-transfer routes** — Ride jeepney A, walk to stop, ride jeepney B
- **2-transfer routes** — Up to 3 jeepney segments

**Map display:**

- Color-coded polylines for each jeepney route segment
- Dotted lines for walking segments
- Route info cards showing distance, estimated time, fare

**Route calculation engine:**

- Primary: `HybridTransitRouter` (graph-based pathfinding)
- Fallback: `RouteMatcher` (OSRM path matching) + `MultiTransferMatcher` (legacy transfers)
- See [ROUTING_SYSTEM.md](ROUTING_SYSTEM.md) for details

**Place search:**

- Powered by Nominatim (OpenStreetMap geocoding API)
- Filtered to Davao City bounding box
- Shows distance from current location

---

## 4. Fare Calculator

### Files

- [screens/fare/fare_calculator_screen.dart](../lib/screens/fare/fare_calculator_screen.dart)
- [screens/fare/map_fare_calculator_screen.dart](../lib/screens/fare/map_fare_calculator_screen.dart)
- [controllers/fare_calculator_controller.dart](../lib/controllers/fare_calculator_controller.dart)
- [services/fare_settings_service.dart](../lib/services/fare_settings_service.dart)

### Description

Users calculate the exact jeepney fare between two points.

**How it works:**

1. **Open map** — User taps the map fare calculator button
2. **Set Point A** — Tap the map to set the origin
3. **Set Point B** — Tap the map to set the destination
4. **See results** — Distance, fare, and matching routes displayed

**Fare calculation formula:**

```
if distance ≤ baseFareDistance (4.0 km):
    fare = baseFare (₱13.00)
else:
    fare = baseFare + (distance - baseFareDistance) × farePerKm (₱1.80)
```

**Discounts:**

- **Student discount**: 20% off
- **Senior/PWD discount**: 20% off

**Fare rates:**

- Configurable by admin via Laravel API
- Cached locally with fallback defaults
- Auto-refresh on app start

**Matching routes:**

- Shows which jeepney routes cover the selected path
- Displays match percentage (how well the route covers the path)
- Point A / Point B markers on the map

**Distance units:**

- Supports km and miles (configurable in Settings)

---

## 5. Landmarks Directory

### Files

- [screens/landmarks/landmarks_screen.dart](../lib/screens/landmarks/landmarks_screen.dart)
- [repositories/landmark_repository.dart](../lib/repositories/landmark_repository.dart)
- [models/landmark.dart](../lib/models/landmark.dart)

### Description

Browse and search Davao City landmarks as navigation reference points.

**Features:**

- **Category filter** — Filter by: City Center, Mall, School, Hospital, Transport, Church, Park, Government, Market, Hotel, Restaurant, Other
- **Search** — Text search across landmark names
- **Featured landmarks** — Sorted to appear first in the list
- **Alphabetical sorting** — Within each group (featured / non-featured)
- **Distance display** — Shows distance from current location (km or miles)
- **Tap to navigate** — Tapping a landmark can open it on the map or set it as a route destination

---

## 6. Profile & Settings

### Files

- [screens/profile/profile_screen.dart](../lib/screens/profile/profile_screen.dart)
- [screens/profile/settings_screen.dart](../lib/screens/profile/settings_screen.dart)
- [screens/profile/about_screen.dart](../lib/screens/profile/about_screen.dart)
- [screens/profile/account_settings_screen.dart](../lib/screens/profile/account_settings_screen.dart)
- [screens/profile/notifications_screen.dart](../lib/screens/profile/notifications_screen.dart)
- [screens/profile/recent_activity_screen.dart](../lib/screens/profile/recent_activity_screen.dart)
- [screens/profile/report_feedback_screen.dart](../lib/screens/profile/report_feedback_screen.dart)
- [services/settings_service.dart](../lib/services/settings_service.dart)

### Description

**Profile Screen:**

- User name, email, role display
- Navigation to sub-screens
- Logout button

**Settings Screen:**

- **Notifications** — Toggle push notifications, sound, vibration
- **Language** — English, Filipino, Cebuano
- **Distance unit** — Kilometers or Miles
- **Location services** — Enable/disable GPS access
- **Tutorial** — Reset and replay the first-time tutorial

**Account Settings:**

- View account details
- Change password
- Delete account

**About Screen:**

- App version, description
- LeJeepney logo
- Credits and links

**Recent Activity Screen:**

- Full history of user actions (routes, fares, tickets)
- Grouped by date
- Pull-to-refresh with server sync

**Notifications Screen:**

- Ticket reply notifications
- Mark as read / mark all as read
- Delete notifications

---

## 7. Support Tickets

### Files

- [screens/support/create_ticket_screen.dart](../lib/screens/support/create_ticket_screen.dart)
- [screens/support/ticket_list_screen.dart](../lib/screens/support/ticket_list_screen.dart)
- [screens/support/ticket_detail_screen.dart](../lib/screens/support/ticket_detail_screen.dart)
- [services/support_service.dart](../lib/services/support_service.dart)
- [services/ticket_notification_service.dart](../lib/services/ticket_notification_service.dart)
- [models/support_ticket.dart](../lib/models/support_ticket.dart)

### Description

Users can submit support tickets and track their status.

**Ticket types** (10 categories):

- Route Issue, Fare Dispute, App Bug, Feature Request, Account Issue,
- Map Problem, Payment Issue, Safety Concern, Driver Complaint, Other

**Ticket priorities:** Low, Medium, High (color-coded)

**Ticket lifecycle:**

```
Pending → In Progress → Resolved
    └──────────────────→ Cancelled
```

**Features:**

- Create ticket with type, priority, subject, description, optional attachment
- View all tickets (filterable by status)
- View ticket details with full reply thread
- Add follow-up messages
- Cancel tickets
- Real-time notification polling (60-second interval)
- Unread badge count on profile

---

## 8. Multi-Language Support

### Files

- [services/localization_service.dart](../lib/services/localization_service.dart)
- [services/settings_service.dart](../lib/services/settings_service.dart)

### Description

The app supports 3 languages with instant switching (no restart needed).

**Supported languages:**
| Code | Language |
|------|----------|
| `en` | English |
| `fil`| Filipino |
| `ceb`| Cebuano |

**How it works:**

- `LocalizationService` holds a static translation map (~50+ keys)
- `SettingsService` stores the selected language in `SharedPreferences`
- `TranslationExtension` on `BuildContext` provides `context.tr('key')` for inline use
- Changing language triggers `MyApp` rebuild via `SettingsService` listener

**Translation categories:** Auth, Navigation, Fare Calculator, Routes, Map, Landmarks, Actions, Status, Errors, Success, Disclaimers

---

## 9. Offline Activity Tracking

### Files

- [services/recent_activity_service_v2.dart](../lib/services/recent_activity_service_v2.dart)
- [services/recent_activity_api_service.dart](../lib/services/recent_activity_api_service.dart)
- [services/activity_sync_manager.dart](../lib/services/activity_sync_manager.dart)
- [database/activity_database.dart](../lib/database/activity_database.dart)
- [models/recent_activity_model.dart](../lib/models/recent_activity_model.dart)

### Description

All user actions are tracked locally and synced to the server.

**Tracked activities:**

- Route calculated
- Fare calculated
- Location searched
- Route saved
- Ticket created / replied / status changed

**Sync strategy:**

- Activities stored in **SQLite** immediately (offline-first)
- Synced to Laravel API when:
  - App starts (full sync)
  - 5+ unsynced activities accumulated (threshold sync)
  - Every 30 minutes (timer sync)
  - Manual pull-to-refresh
- Batch sync with fallback to individual sync
- Connectivity-aware (skips sync when offline)
- Max 50 activities stored locally, 90-day auto-cleanup

---

## 10. Map System

### Files

- [widgets/map/app_map.dart](../lib/widgets/map/app_map.dart)
- [widgets/map/map_markers.dart](../lib/widgets/map/map_markers.dart)
- [services/walking_route_service.dart](../lib/services/walking_route_service.dart)
- [utils/resilient_tile_provider.dart](../lib/utils/resilient_tile_provider.dart)
- [constants/map_constants.dart](../lib/constants/map_constants.dart)

### Description

Maps are rendered using **flutter_map** with **OpenStreetMap** tiles.

**Features:**

- Default center: Davao City (7.0731°N, 125.6128°E)
- Zoom range: 10–18
- Resilient tile provider with error handling
- Walking path polylines (dotted lines)
- Jeepney route polylines (colored solid lines)
- Custom markers for origin, destination, landmarks
- GPS location tracking

**Walking routes:**

- Primary API: OpenRouteService
- Fallback: OSRM foot profile
- Final fallback: Straight line
- LRU cache (50 entries) to avoid redundant API calls
