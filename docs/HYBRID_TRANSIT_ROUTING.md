# Hybrid Transit Routing System

## Overview

The Hybrid Transit Routing System is an advanced algorithm for the Lejeepney Flutter app that combines OSRM path validation with jeepney-based pathfinding. The system automatically falls back to a pure jeepney-based approach when OSRM-generated paths have poor coverage by actual jeepney routes.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    HybridTransitRouter                          │
│  ┌─────────────────┐    ┌──────────────────────────────────┐   │
│  │ RouteValidator  │    │        JeepneyPathfinder         │   │
│  │                 │    │  ┌────────────────────────────┐  │   │
│  │ - Validate OSRM │    │  │      TransitGraph          │  │   │
│  │ - Check coverage│    │  │  - Route intersections    │  │   │
│  │ - Find gaps     │    │  │  - Transfer points        │  │   │
│  └────────┬────────┘    │  │  - Connectivity graph     │  │   │
│           │             │  └────────────────────────────┘  │   │
│           │             │                                   │   │
│           v             │  Strategies:                      │   │
│     Coverage >= 40%     │  1. Direct routes (0 transfers)   │   │
│     Gap <= 500m         │  2. One transfer (2 jeepneys)     │   │
│           ?             │  3. Two transfers (3 jeepneys)    │   │
│          / \            └──────────────────────────────────┘   │
│        Yes   No                                                 │
│         │     │                                                 │
│         v     v                                                 │
│   Use OSRM  Use Jeepney-Based                                  │
│   Results   Pathfinder                                          │
│         \     /                                                 │
│          v   v                                                  │
│    ┌───────────────┐                                           │
│    │ Merge & Rank  │                                           │
│    │   Results     │                                           │
│    └───────────────┘                                           │
└─────────────────────────────────────────────────────────────────┘
```

## File Structure

```
lib/utils/transit_routing/
├── transit_routing.dart      # Barrel export file
├── models.dart               # Data models and configuration
├── geo_utils.dart            # Geographic utility functions
├── route_validator.dart      # OSRM path validation
├── transit_graph.dart        # Route graph and intersections
├── jeepney_pathfinder.dart   # Jeepney-only pathfinding
└── hybrid_router.dart        # Main hybrid routing logic
```

## Data Models

### TransitNode

Represents a point in the transit network graph.

- Types: `routeEndpoint`, `intersection`, `userOrigin`, `userDestination`, `accessPoint`
- Contains location, name, and connected route IDs

### TransitEdge

Represents a connection between two nodes.

- Types: `jeepneyRide`, `walking`, `transfer`
- Contains distance, estimated time, and fare

### JourneySegment

A single segment of a complete journey.

- Types: `walking`, `transfer`, `jeepneyRide`
- Contains route info, distance, fare, and estimated time

### SuggestedRoute

Complete route suggestion from origin to destination.

- Contains list of segments, total fare, distance, walking distance
- Includes transfer count and scoring

### HybridRoutingConfig

Configuration constants for the routing system:

```dart
const HybridRoutingConfig({
  this.minCoveragePercentage = 40.0,      // Min OSRM coverage
  this.maxCoverageGapMeters = 500.0,      // Max gap in coverage
  this.maxAccessWalkingMeters = 500.0,    // Max walk to first stop
  this.maxTransferWalkingMeters = 300.0,  // Max walk between transfers
  this.maxTransfers = 2,                   // Max number of transfers
  this.maxResults = 5,                     // Max route suggestions
  this.walkingSpeedKmh = 4.0,             // Walking speed estimation
  this.jeepneySpeedKmh = 15.0,            // Jeepney speed estimation
});
```

## Algorithm Flow

### Step 1: Route Validation (RouteAccuracyValidator)

When an OSRM path is provided:

1. Sample the path (100 points max)
2. Check each point against all jeepney routes (150m buffer)
3. Calculate coverage percentage
4. Find maximum gap in coverage
5. Determine if path is "accurate" (≥40% coverage, ≤500m gaps)

```dart
RouteValidationResult validate({
  required List<LatLng> osrmPath,
  required List<JeepneyRoute> jeepneyRoutes,
});
```

### Step 2: Build Transit Graph (TransitGraph)

Creates a network graph of jeepney routes:

1. Add route endpoints as nodes
2. Find route intersections (routes within 300m of each other)
3. Add intersection nodes with landmark names
4. Build edges connecting nodes along routes

### Step 3: Find Routes (JeepneyPathfinder)

Three strategies executed in order:

#### Strategy 1: Direct Routes

- Find routes accessible from origin (within 500m)
- Find routes accessible from destination
- Match routes that appear in both lists
- Build journey segments (walk → ride → walk)

#### Strategy 2: One Transfer Routes

- For each origin route, find its intersections
- Check if connecting routes can reach destination
- Build 5-segment journey (walk → ride → transfer → ride → walk)

#### Strategy 3: Two Transfer Routes

- Extend one-transfer logic with additional hop
- Find routes that connect to intermediate routes
- Build 7-segment journey

### Step 4: Scoring Algorithm

Routes are scored (lower = better):

```dart
score = (transferCount * 40.0) +     // Fewer transfers preferred
        (totalFare * 2.0) +           // Lower fare preferred
        (totalWalkingKm * 100.0) +    // Less walking preferred
        (estimatedMinutes * 1.0) -    // Faster routes preferred
        (shortDistance ? 5 : 0);      // Bonus for short routes
```

### Step 5: Hybrid Decision

```dart
if (osrmPath != null && osrmPath.isNotEmpty) {
  // Validate OSRM path
  validationResult = validator.validate(osrmPath, routes);

  if (validationResult.isAccurate) {
    // Use OSRM-matched routes as primary
    primarySource = RouteSourceType.osrmValidated;
  }
}

if (!isAccurate || osrmPath == null) {
  // Fallback to jeepney-based pathfinding
  primarySource = RouteSourceType.jeepneyBased;
}

// Merge and rank all results
return mergeAndRank([osrmRoutes, jeepneyRoutes]);
```

## Geographic Utilities (GeoUtils)

Common functions used throughout:

- `haversineDistance(p1, p2)` - Great-circle distance
- `distanceMeters(p1, p2)` - Distance in meters
- `minDistanceToPath(point, path)` - Nearest distance to polyline
- `findClosestPointOnPath(point, path)` - Closest point on path
- `pathLength(path)` - Total length of a path
- `samplePath(path, maxPoints)` - Reduce path points
- `getBoundingBox(path)` - Get path bounds
- `estimateWalkingTime(distanceKm)` - Time estimation
- `estimateJeepneyTime(distanceKm)` - Time estimation

## Fare Calculation

```dart
double _calculateFare(JeepneyRoute route, double distanceKm) {
  const baseFareDistance = 4.0;  // km
  const perKmRate = 1.50;        // ₱/km

  if (distanceKm <= baseFareDistance) {
    return route.baseFare;
  }

  final additionalKm = distanceKm - baseFareDistance;
  return route.baseFare + (additionalKm * perKmRate);
}
```

## User Location Integration

The map fare calculator now supports GPS location:

1. Initializes location service on screen load
2. Shows "Use My Current Location" button
3. Displays blue dot marker for user position
4. Can set Point A to current GPS coordinates

## UI Components

### HybridRoutingResult Display

Shows routing source badge:

- **Validated** (green) - OSRM path has good jeepney coverage
- **Jeepney-Based** (orange) - Fallback algorithm used

### \_buildHybridRouteCard

Displays suggested routes with:

- Rank badge (gold/silver/bronze)
- Transfer count badge
- Route sequence (e.g., "04D → 12A → 15")
- Segment details with individual fares
- Walking instructions at each step
- Summary with total fare, distance, time

## Performance Considerations

1. **Path Sampling**: Reduces computation by sampling paths to max 50-100 points
2. **Bounding Box Check**: Quick rejection of non-overlapping routes
3. **Early Termination**: Stops when enough results found
4. **Graph Caching**: TransitGraph is rebuilt only when routes change
5. **Parallel Legacy Matching**: Still runs old matcher for backward compatibility

## Testing Scenarios

### Scenario 1: Direct Route Available

- User: Davao City Hall → SM City Davao
- Route 04D covers 85% of path
- **Result**: Direct route suggestion with ₱13 fare

### Scenario 2: OSRM Path Inaccurate

- User: Remote area → Downtown
- OSRM suggests route through non-jeepney area
- Coverage: 25%
- **Result**: Fallback to jeepney-based, finds Route 12A → Route 04D

### Scenario 3: Two Transfers Needed

- User: Toril → Panacan
- No single route covers both
- **Result**: Route 35 → Route 04D → Route 27 with 2 transfers

### Scenario 4: No Routes Available

- User: Outside jeepney service area
- **Result**: Empty results, placeholder shown

## Future Improvements

1. **Real-time Traffic**: Consider congestion in time estimates
2. **User Preferences**: Allow preference for fewer transfers vs lower fare
3. **Route Caching**: Pre-calculate common route combinations
4. **ML Ranking**: Learn from user selections to improve scoring
5. **Time-based Routing**: Consider jeepney schedules/availability
6. **Walking Directions**: Integrate with walking navigation

## API Dependencies

Required endpoints:

- `GET /api/v1/routes` - All jeepney routes with paths
- `GET /api/v1/landmarks` - Landmarks for transfer point naming

## Changelog

| Version | Date       | Changes                               |
| ------- | ---------- | ------------------------------------- |
| 1.0.0   | 2026-01-25 | Initial hybrid routing implementation |
| 1.0.0   | 2026-01-25 | Route accuracy validator              |
| 1.0.0   | 2026-01-25 | Transit graph with intersections      |
| 1.0.0   | 2026-01-25 | Jeepney-based pathfinder              |
| 1.0.0   | 2026-01-25 | GPS location integration              |
| 1.0.0   | 2026-01-25 | Hybrid route card UI                  |
