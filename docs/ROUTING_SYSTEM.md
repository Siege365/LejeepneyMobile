# Routing System

This document provides a deep dive into LeJeepney's transit routing engine — the system that finds the best jeepney routes between any two points in Davao City.

---

## Overview

The routing system uses a **hybrid approach** combining:

1. **Graph-based pathfinding** — Pre-built transit network graph with Dijkstra-like traversal
2. **OSRM validation** — Walking path matching against jeepney route coverage
3. **Legacy matchers** — Buffer-based route overlap detection (backward compatibility)

```
                    User: "Point A → Point B"
                              │
                    RouteCalculationService
                    ┌─────────┼──────────┐
                    ▼         ▼          ▼
            HybridTransit  RouteMatcher  MultiTransfer
              Router       (legacy)      Matcher (legacy)
                │
        ┌───────┼────────┐
        ▼       ▼        ▼
    Transit  Jeepney   Route
    Graph    Pathfinder Validator
```

---

## Core Files

| File                                                | Purpose                                                |
| --------------------------------------------------- | ------------------------------------------------------ |
| `lib/utils/transit_routing/hybrid_router.dart`      | Main orchestrator — combines OSRM + graph pathfinding  |
| `lib/utils/transit_routing/transit_graph.dart`      | Builds the jeepney network graph                       |
| `lib/utils/transit_routing/jeepney_pathfinder.dart` | Graph traversal — finds routes                         |
| `lib/utils/transit_routing/route_validator.dart`    | Validates OSRM paths against jeepney coverage          |
| `lib/utils/transit_routing/geo_utils.dart`          | Geographic calculations (haversine, bearing, etc.)     |
| `lib/utils/transit_routing/models.dart`             | Data models (TransitNode, TransitEdge, SuggestedRoute) |
| `lib/utils/route_matcher.dart`                      | Legacy: OSRM path → jeepney route matching             |
| `lib/utils/multi_transfer_matcher.dart`             | Legacy: Multi-transfer route combinations              |
| `lib/services/route_calculation_service.dart`       | Top-level orchestrator                                 |
| `lib/services/walking_route_service.dart`           | Walking direction fetcher                              |

---

## Data Models

### TransitNode

A point in the transit network graph.

```
TransitNode
├── id: String (unique identifier)
├── type: TransitNodeType
│   ├── endpoint    — terminal/start/end of a route
│   └── intersection — where two routes cross
├── position: LatLng
└── routeIds: Set<String> — which routes pass through this node
```

### TransitEdge

A connection between two nodes.

```
TransitEdge
├── from: String (node ID)
├── to: String (node ID)
├── type: TransitEdgeType
│   ├── ride    — riding a jeepney
│   └── walking — walking between stops
├── routeId: String?
├── distance: double (meters)
└── path: List<LatLng> (polyline coordinates)
```

### JourneySegment

One leg of a suggested route.

```
JourneySegment
├── type: JourneySegmentType
│   ├── walk  — walking to/from/between stops
│   └── ride  — riding a jeepney
├── routeId: String?
├── routeName: String?
├── routeColor: Color?
├── path: List<LatLng>
├── distance: double (meters)
└── duration: double (seconds)
```

### SuggestedRoute

A complete route suggestion from origin to destination.

```
SuggestedRoute
├── segments: List<JourneySegment>
├── totalDistance: double (meters)
├── totalDuration: double (seconds)
├── transfers: int (number of jeepney changes)
├── score: double (ranking score, lower = better)
├── source: RouteSourceType
│   ├── graphPathfinder — from JeepneyPathfinder
│   ├── osrmValidated   — from OSRM + validation
│   └── legacy          — from old matchers
├── isDirectRoute: bool (0 transfers)
└── fareEstimate: double?
```

### HybridRoutingConfig

Configuration for the routing engine.

| Parameter            | Default | Description                           |
| -------------------- | ------- | ------------------------------------- |
| `minCoverage`        | 40%     | Minimum jeepney route coverage needed |
| `maxAccessWalking`   | 1000m   | Max walk to first jeepney stop        |
| `maxTransferWalking` | 300m    | Max walk between transfers            |
| `maxTransfers`       | 2       | Maximum number of jeepney changes     |

---

## How the Transit Graph Works

### Building the Graph

The `TransitGraph` builds a network from all `JeepneyRoute` objects:

```
Input: List<JeepneyRoute> (each with path: List<LatLng>)

Step 1: Create endpoint nodes
  For each route → create nodes at start and end of path

Step 2: Find intersections (bounding box optimization)
  For each pair of routes:
    If bounding boxes overlap:
      Walk both paths, find points where they come within ~50m
      Create intersection nodes

Step 3: Create edges
  For each route:
    Connect its nodes with "ride" edges
    Calculate distance using path coordinates

Step 4: Add walking edges
  Between intersection nodes that are close enough
  (within maxTransferWalking distance)
```

**Performance optimization:**

- Bounding box pre-filtering eliminates most route pair comparisons
- Built on a separate isolate via `compute()` to avoid blocking the UI
- Cached for 1 hour

### Graph Example

```
Route 05B: Terminal ──────────────── Destination
                        ╳ (intersection)
Route 08A: Terminal ──────────────── Destination

Nodes: [05B-start, 05B-end, 08A-start, 08A-end, intersection]
Edges: [05B ride, 08A ride, walking (intersection)]
```

---

## JeepneyPathfinder — Route Finding

### Algorithm

The `JeepneyPathfinder` uses the transit graph to find routes with 3 strategies:

#### Strategy 1: Direct Routes (0 transfers)

```
For each jeepney route:
  1. Find the closest point on the route to the origin
  2. Find the closest point on the route to the destination
  3. Check: both within maxAccessWalking (1000m)?
  4. Check: direction is forward (origin point comes before destination on path)?
  5. If valid: Create SuggestedRoute with [walk, ride, walk] segments
```

#### Strategy 2: One Transfer (1 transfer)

```
For each pair of routes (A, B):
  1. Find intersection points between A and B
  2. Check: origin close to A's path?
  3. Check: destination close to B's path?
  4. Check: transfer walk distance within limit (300m)?
  5. Check: direction is forward on both routes?
  6. If valid: Create SuggestedRoute with [walk, ride A, walk, ride B, walk]
```

#### Strategy 3: Two Transfers (2 transfers)

```
For each triple of routes (A, B, C):
  1. Find intersection A↔B and B↔C
  2. Check: origin close to A, destination close to C
  3. Check: transfer walks within limits
  4. Check: forward travel on all three routes
  5. If valid: Create SuggestedRoute with [walk, ride A, walk, ride B, walk, ride C, walk]
```

### Direction Enforcement

A critical feature: jeepneys travel in one direction. The pathfinder enforces forward travel:

```
isForwardTravel(path, boardPoint, alightPoint):
  boardIndex = index of closest point on path to boardPoint
  alightIndex = index of closest point on path to alightPoint
  return boardIndex < alightIndex  // Must board before alighting
```

### Scoring

Routes are ranked by a composite score:

```
score = totalDistance × 0.3
      + totalDuration × 0.3
      + transfers × 1000  // Heavy penalty for transfers
      + walkingDistance × 0.4  // Penalize long walks
```

Lower score = better route.

---

## HybridTransitRouter — The Orchestrator

### How It Combines Results

```
HybridTransitRouter.findRoutes(origin, destination):

  1. Run JeepneyPathfinder.findRoutes() → graph-based results
  2. Optionally validate with OSRM:
     a. Fetch OSRM walking path
     b. Use RouteAccuracyValidator to check coverage
     c. If coverage < 40%, flag as less reliable

  3. Merge and rank all results
  4. Deduplicate (same routes, similar paths)
  5. Return top results sorted by score
```

### Pre-initialization

To avoid slow first search:

```
AppDataPreloader.initialize():
  └── AppDataPreloader.preInitialize():
        └── HybridTransitRouter.preInitialize():
              ├── TransitGraph.build(routes)     // Heavy work
              └── JeepneyPathfinder.create()     // Uses compute()

  (runs in background, non-blocking)
```

When a user searches:

```
RouteCalculationService.calculateRoute():
  └── AppDataPreloader.ensureGraphReady()  // Awaits if still building
  └── HybridTransitRouter.findRoutes()     // Graph ready, instant
```

---

## RouteAccuracyValidator

Validates how well an OSRM walking path aligns with jeepney routes.

### How It Works

```
Input: OSRM path (walking directions), List<JeepneyRoute>

1. Sample points along the OSRM path (every ~50m)
2. For each sample point:
   - Find the closest jeepney route
   - Check if distance to route < buffer (100m)
   - If yes: point is "covered"
3. Coverage = covered points / total points
4. If coverage ≥ 40%: path is valid for jeepney routing
```

### Coverage Analysis

```
RouteValidationResult:
├── isValid: bool
├── coveragePercentage: double (0-100%)
├── coveringRoutes: List<JeepneyRoute>
└── uncoveredSegments: List<LatLng> (gaps in coverage)
```

---

## Legacy Matchers (Backward Compatibility)

### RouteMatcher

Matches OSRM walking paths against individual jeepney routes using buffer-based overlap.

```
RouteMatcher.matchRoutes(osrmPath, allRoutes):
  For each route:
    1. Bounding box pre-filter (skip if no overlap)
    2. Walk the OSRM path, check each point against route path
    3. Use 100m buffer for "close enough"
    4. Calculate match percentage (overlap / total)
    5. If match ≥ 50%: include in results

  Return: List<RouteMatchResult>
    ├── route: JeepneyRoute
    ├── matchPercentage: double
    ├── coveragePercentage: double
    └── overlapDistanceKm: double
```

### MultiTransferMatcher

Finds multi-transfer routes by analyzing route intersections.

```
MultiTransferMatcher.findMultiTransferRoutes(origin, destination, routes):

  1. findTwoSegmentRoutes() — 1 transfer:
     For each pair (A, B):
       If A covers origin area AND B covers destination area
       AND A intersects B (within 500m):
         Create TransferPoint at intersection
         Create MultiTransferRoute [A, walk, B]

  2. findThreeSegmentRoutes() — 2 transfers:
     For each triple (A, B, C):
       Similar logic with two transfer points

  3. findMidpointTransferRoutes() — midpoint-based:
     Calculate geographic midpoint between origin/destination
     Find routes near midpoint for transfers
```

---

## Walking Route Service

Fetches actual pedestrian walking polylines for map display.

### API Priority

```
1. OpenRouteService API (primary)
   URL: https://api.openrouteservice.org/v2/directions/foot-walking
   Requires: API key
   Returns: GeoJSON polyline

2. OSRM Foot Profile (fallback)
   URL: https://router.project-osrm.org/route/v1/foot/{coords}
   Requires: Nothing
   Returns: Encoded polyline

3. Straight Line (final fallback)
   If both APIs fail, draw a straight line between points
```

### Caching

- LRU cache with 50 entries
- Key: rounded coordinates (3 decimal places)
- Avoids redundant API calls for nearby searches

---

## GeoUtils — Geographic Utilities

Core geographic calculations used throughout the routing system.

| Method                                | Description                             | Used For                      |
| ------------------------------------- | --------------------------------------- | ----------------------------- |
| `haversineDistance(a, b)`             | Distance between two points (km)        | All distance calculations     |
| `distanceMeters(a, b)`                | Distance in meters                      | Threshold checks              |
| `minDistanceToPath(point, path)`      | Closest distance from point to polyline | "Is this point near a route?" |
| `findClosestPointOnPath(point, path)` | Nearest point on a polyline             | Board/alight point detection  |
| `samplePath(path, intervalM)`         | Sample points along a path              | Coverage analysis             |
| `getBoundingBox(path)`                | Get lat/lng bounds of a path            | Pre-filtering optimization    |
| `isForwardTravel(path, a, b)`         | Is point A before point B on path?      | Direction enforcement         |
| `extractSubPath(path, from, to)`      | Get portion of path between two points  | Segment extraction            |
| `calculateBearing(from, to)`          | Compass bearing between points          | Direction display             |
| `estimateWalkingTime(distKm)`         | Walking duration at 4 km/h              | Time estimates                |
| `estimateJeepneyTime(distKm)`         | Jeepney duration at 15 km/h             | Time estimates                |

---

## Performance Characteristics

| Operation              | Typical Time | Notes                          |
| ---------------------- | ------------ | ------------------------------ |
| Graph build            | 1–3 seconds  | Runs on isolate, cached 1 hour |
| Direct route search    | <100ms       | Simple path proximity checks   |
| 1-transfer search      | 100–500ms    | Pairwise route intersection    |
| 2-transfer search      | 500ms–2s     | Triple route combinations      |
| OSRM walking path      | 200–500ms    | Network call, cached           |
| Full route calculation | 1–3 seconds  | All strategies combined        |

---

## Configuration Constants

```dart
// HybridRoutingConfig defaults
minCoverage: 0.4          // 40% route coverage needed
maxAccessWalking: 1000.0  // 1km max walk to first stop
maxTransferWalking: 300.0 // 300m max walk between transfers
maxTransfers: 2           // Up to 2 transfers

// GeoUtils
walkingSpeed: 4.0         // km/h
jeepneySpeed: 15.0        // km/h average (traffic considered)

// RouteMatcher
matchBuffer: 100.0        // 100m buffer for route matching
minMatchPercentage: 0.5   // 50% minimum overlap

// TransitGraph
intersectionThreshold: 50.0  // 50m to detect route crossings
```
