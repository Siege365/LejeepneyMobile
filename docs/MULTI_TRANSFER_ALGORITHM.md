# Multi-Transfer Route Algorithm Implementation

## Overview

This document describes the implementation of the multi-transfer route algorithm for the Lejeepney Flutter app. The algorithm finds optimal jeepney route combinations when no direct route is available between the user's origin and destination.

## Files Created/Modified

### New Files

1. **`lib/utils/multi_transfer_matcher.dart`** - Core algorithm utility
2. **`lib/utils/route_display_helpers.dart`** - Helper functions for route display

### Modified Files

1. **`lib/screens/fare/map_fare_calculator_screen.dart`** - Integrated multi-transfer matching
2. **`lib/screens/fare/fare_calculator_screen.dart`** - Added multi-transfer route UI cards
3. **`lib/screens/search/search_screen.dart`** - Enhanced route display with direction arrows

---

## Algorithm Architecture

### Phase 1: Direct Route Matching (Existing)

Located in `lib/utils/route_matcher.dart`:

- Uses buffer-based path matching (150m buffer)
- Calculates match percentage based on point coverage
- Returns top 5 matching routes with ≥50% match

### Phase 2: Multi-Transfer Matching (New)

Located in `lib/utils/multi_transfer_matcher.dart`:

#### Data Models

```dart
/// Transfer point between two routes
class TransferPoint {
  final LatLng location;
  final String? landmarkName;
  final double walkingDistanceMeters;
  final JeepneyRoute fromRoute;
  final JeepneyRoute toRoute;
}

/// Single segment of a multi-transfer route
class RouteSegment {
  final JeepneyRoute route;
  final LatLng startPoint;
  final LatLng endPoint;
  final double distanceKm;
  final double fare;
  final double matchPercentage;
}

/// Complete multi-transfer solution
class MultiTransferRoute {
  final List<RouteSegment> segments;
  final List<TransferPoint> transferPoints;
  final double totalFare;
  final double totalDistanceKm;
  final double totalWalkingDistanceMeters;
  final int transferCount;
  final double score; // Lower is better
}
```

#### Algorithm Flow

```
1. User selects Point A and Point B on map
2. Calculate road-snapped route path (OSRM)
3. Try direct route matching (RouteMatcher)
4. If direct routes found → Display direct routes
5. If NO direct routes (or < 2 results):
   │
   ├─→ Find Route Intersections
   │   - Compare all route pairs
   │   - Find closest points between paths
   │   - Filter by max walking distance (300m)
   │
   ├─→ Try 2-Segment Routes (1 transfer)
   │   - Split user path at 25%, 50%, 75%
   │   - Find matching routes for each segment
   │   - Calculate transfer walking distance
   │
   ├─→ Try 3-Segment Routes (2 transfers)
   │   - Split path at 33% and 66%
   │   - Find matching routes for each third
   │   - Calculate both transfer walking distances
   │
   └─→ Score and Rank Results
       - Transfer penalty: +50 points per transfer
       - Fare weight: +2 per peso
       - Walking weight: +0.1 per meter
       - Match bonus: -(100 - avgMatchPercentage)
```

---

## Key Algorithm Components

### 1. Route Intersection Detection

```dart
static List<Map<String, dynamic>> _findRouteIntersections(
  List<JeepneyRoute> routes,
) {
  // For each pair of routes:
  // - Sample both paths (30 points each)
  // - Find minimum distance between any two points
  // - If distance ≤ 300m, record as potential transfer point
}
```

### 2. Path Segmentation

**Two-Segment (1 Transfer):**

```dart
// Split at 25%, 50%, 75% of path length
final splitPoints = [0.25, 0.5, 0.75];
final splitIndex = (userPath.length * splitRatio).floor();
final firstHalf = userPath.sublist(0, splitIndex + 1);
final secondHalf = userPath.sublist(splitIndex);
```

**Three-Segment (2 Transfers):**

```dart
// Split at 33% and 66%
final firstThird = (userPath.length * 0.33).floor();
final secondThird = (userPath.length * 0.66).floor();
final segment1 = userPath.sublist(0, firstThird + 1);
final segment2 = userPath.sublist(firstThird, secondThird + 1);
final segment3 = userPath.sublist(secondThird);
```

### 3. Landmark Integration

Transfer points are enhanced with landmark names from the database:

```dart
static Map<String, dynamic>? _findNearestLandmark(
  LatLng point,
  List<Map<String, dynamic>> landmarks,
) {
  // Find landmark within 200m of transfer point
  // Returns landmark name and ID for display
}
```

### 4. Scoring Algorithm

Lower score = better route:

```dart
final score =
  (segments.length - 1) * 50.0 +   // Transfer penalty
  totalFare * 2.0 +                 // Fare weight
  totalWalking / 10.0 +             // Walking distance
  (100 - avgMatchPercentage);       // Match quality bonus
```

---

## Configuration Constants

| Constant             | Value  | Purpose                       |
| -------------------- | ------ | ----------------------------- |
| `maxWalkingDistance` | 300m   | Max walking between transfers |
| `maxTransfers`       | 2      | Maximum number of transfers   |
| `bufferMeters`       | 150m   | Route matching buffer         |
| `minMatchPercentage` | 35-50% | Minimum segment match %       |
| `maxResults`         | 5      | Number of results to return   |

---

## UI Implementation

### Multi-Transfer Route Card

The `_buildMultiTransferCard` method in `fare_calculator_screen.dart` displays:

1. **Header Section:**
   - Rank badge (gold/silver/bronze/number)
   - Transfer count badge (orange pill)
   - Route sequence (e.g., "04D → 12A → 15")

2. **Segment Details:**
   - Numbered circles for each segment
   - Route name and number
   - Segment fare
   - Walking instructions between segments

3. **Summary Section:**
   - Total fare (green)
   - Total distance
   - Total walking distance

---

## Route Display Enhancements

### Direction Arrows (`route_display_helpers.dart`)

```dart
// Calculate arrow positions every 500m
List<ArrowPoint> calculateArrowPoints(List<LatLng> path, double intervalMeters)

// Calculate bearing for arrow rotation
double calculateBearing(LatLng from, LatLng to)

// Get contrast color for arrow visibility
Color getContrastColor(Color backgroundColor)
```

### Start/End Markers

- **START:** Green circle with play icon + label
- **END:** Red circle with stop icon + label
- Enhanced shadows and glowing effects

---

## Testing Scenarios

### Scenario 1: Direct Route Available

- User path covers 70% of Route 04D
- **Result:** Shows Route 04D as #1 with 70% match

### Scenario 2: One Transfer Needed

- User wants to go from Maa to SM Lanang
- No single route covers both areas
- **Result:** Shows "Route 04D → Route 12A" with transfer at Bankerohan

### Scenario 3: Two Transfers Needed

- Complex journey across multiple zones
- **Result:** Shows 3-route combination with 2 transfer points

### Scenario 4: No Routes Available

- User is in an area with no jeepney coverage
- **Result:** Shows placeholder "No routes found"

---

## Performance Optimizations

1. **Path Sampling:** Reduce points to 30-50 for calculations
2. **Bounding Box Check:** Quick rejection of non-overlapping routes
3. **Early Termination:** Stop if enough results found
4. **Limit Combinations:** Max 3 segments, top 5 results

---

## Future Improvements

1. **Real-time Updates:** Consider traffic/availability
2. **Time Estimates:** Add estimated travel time
3. **User Preferences:** Let users prefer fewer transfers vs lower fare
4. **Route Visualization:** Show multi-segment routes on map
5. **Cached Intersections:** Pre-calculate route intersection points
6. **ML Optimization:** Learn from user choices to improve ranking

---

## API Dependencies

The algorithm requires these API endpoints:

1. **`GET /api/routes`** - All jeepney routes with path geometry
2. **`GET /api/landmarks`** - Landmarks for transfer point naming

---

## Changelog

| Date       | Version | Changes                                         |
| ---------- | ------- | ----------------------------------------------- |
| 2026-01-25 | 1.0.0   | Initial multi-transfer algorithm implementation |
| 2026-01-25 | 1.0.0   | Added route display with direction arrows       |
| 2026-01-25 | 1.0.0   | Integrated landmark-based transfer points       |
| 2026-01-25 | 1.0.0   | Added UI cards for multi-transfer routes        |
