# Performance Optimization Guide

## Current Performance Analysis

Based on your logs:

```
[API] Routes response received (1323873 bytes) - 1.3MB payload
[TransitGraph] Graph built: 1198 nodes, 4492 edges in 8129ms - 8 seconds BLOCKING
[Pathfinder] Total: 27 routes found in 183ms - Fast ✓
[HybridRouter] Final result: 5 routes, took 8976ms - 9 seconds total
Skipped 45 frames! - Main thread blocked
```

**Primary Bottleneck:** Graph building (8129ms / 8 seconds) blocks main thread

---

## ✅ Already Implemented Optimizations

### 1. **Async Graph Building** ✓

- `JeepneyPathfinder.createAsync()` - Uses isolate via `Future.delayed(Duration.zero)`
- `HybridRouter.preInitialize()` - Builds graph when routes are fetched
- **Status:** ✅ Implemented and awaited in search_screen.dart

### 2. **Bounding Box Caching** ✓

- Pre-computed route bounding boxes stored in `_routeBoundingBoxes`
- Skips 39 intersection checks (3% reduction)
- **Impact:** Minimal - only 39/1225 pairs skipped

### 3. **Reduced Path Sampling** ✓

- Route validation: 100 → 40 points (60% reduction)
- Coverage analysis: 50 → 25 points (50% reduction)
- **Impact:** Faster OSRM validation

### 4. **API Retry Logic** ✓

- 3 retries with exponential backoff
- 90-second timeout
- **Impact:** Prevents connection failures

### 5. **Deduplication Improvements** ✓

- Direct routes: Prevents duplicate route IDs
- Merge: More permissive key (allows variations)
- **Impact:** Returns 5 unique routes instead of 1

---

## 🚀 Additional Optimizations to Implement

### **Priority 1: Cache Built Graph (Biggest Impact)**

The graph is rebuilt every time you calculate routes! Cache it:

```dart
// In HybridTransitRouter class
DateTime? _graphBuildTime;
static const _graphCacheValidDuration = Duration(hours: 1);

Future<void> preInitialize({
  required List<JeepneyRoute> routes,
  List<Map<String, dynamic>>? landmarks,
}) async {
  // Check if cache is still valid
  if (_pathfinder != null &&
      _graphBuildTime != null &&
      DateTime.now().difference(_graphBuildTime!) < _graphCacheValidDuration) {
    debugPrint('[HybridRouter] Using cached graph (age: ${DateTime.now().difference(_graphBuildTime!).inMinutes}min)');
    return;
  }

  // Build new graph
  _pathfinder = await JeepneyPathfinder.createAsync(...);
  _graphBuildTime = DateTime.now();
  debugPrint('[HybridRouter] Graph cached at ${_graphBuildTime}');
}
```

**Expected Impact:** Graph builds once per session → **8 seconds saved on subsequent calculations**

---

### **Priority 2: Reduce Intersection Complexity**

Currently checking **1,225 route pairs** (50×49/2). Reduce to nearby routes only:

```dart
// In TransitGraph._findIntersections()
void _findIntersections() {
  // Group routes by geographic region (grid-based spatial indexing)
  final routesByRegion = _groupRoutesByRegion(_routes);

  for (final region in routesByRegion.values) {
    // Only check intersections within same region
    for (int i = 0; i < region.length; i++) {
      for (int j = i + 1; j < region.length; j++) {
        // Check intersection
      }
    }
  }
}

Map<String, List<JeepneyRoute>> _groupRoutesByRegion(List<JeepneyRoute> routes) {
  const gridSize = 0.05; // ~5km grid cells
  final regions = <String, List<JeepneyRoute>>{};

  for (final route in routes) {
    if (route.path.isEmpty) continue;
    final center = route.path[route.path.length ~/ 2];
    final regionKey = '${(center.latitude / gridSize).floor()}_${(center.longitude / gridSize).floor()}';
    regions.putIfAbsent(regionKey, () => []).add(route);
  }

  return regions;
}
```

**Expected Impact:** Reduce from 1,225 → ~400 checks → **2-3 seconds saved**

---

### **Priority 3: Compress API Response**

1.3MB JSON is large. Use compression:

**Backend (Laravel):**

```php
// In routes controller
return response()->json($data)
    ->header('Content-Encoding', 'gzip');
```

**Or use binary format (Protocol Buffers/MessagePack):**

- 1.3MB JSON → ~400KB binary
- Faster parsing

**Expected Impact:** **50-70% smaller payload**, faster network transfer

---

### **Priority 4: Cache API Response Locally**

Use `shared_preferences` or `hive` to cache routes:

```dart
import 'package:shared_preferences/shared_preferences.dart';

Future<List<JeepneyRoute>> fetchAllRoutes() async {
  final prefs = await SharedPreferences.getInstance();
  final cachedData = prefs.getString('cached_routes');
  final cacheTime = prefs.getInt('routes_cache_time');

  // Use cache if < 1 hour old
  if (cachedData != null && cacheTime != null) {
    final age = DateTime.now().millisecondsSinceEpoch - cacheTime;
    if (age < Duration(hours: 1).inMilliseconds) {
      debugPrint('[API] Using cached routes (${age ~/ 60000}min old)');
      return parseRoutes(cachedData);
    }
  }

  // Fetch fresh data
  final routes = await _fetchFromNetwork();

  // Cache it
  await prefs.setString('cached_routes', jsonEncode(routes));
  await prefs.setInt('routes_cache_time', DateTime.now().millisecondsSinceEpoch);

  return routes;
}
```

**Expected Impact:** **0ms load time** after first fetch

---

### **Priority 5: Lazy Load Route Path Data**

Don't load full path coordinates for all 50 routes initially:

**Modified API Response:**

```json
{
  "routes": [
    {
      "id": 1,
      "name": "Route A",
      "path_summary": "encoded_polyline_or_bbox" // Lightweight
      // path: null  // Load on demand
    }
  ]
}
```

**Load full path only when:**

- User selects route
- Route calculation needs it

**Expected Impact:** **50-70% smaller initial payload**

---

### **Priority 6: Web Workers / Isolates for Graph Building**

Current `Future.delayed(Duration.zero)` doesn't use true background thread.

Use `compute()` for true isolation:

```dart
import 'package:flutter/foundation.dart' show compute;

static Future<TransitGraph> _buildGraphInIsolate(_GraphBuildParams params) async {
  final graph = TransitGraph(
    routes: params.routes,
    landmarks: params.landmarks,
    config: params.config,
  );
  graph.build();
  return graph;
}

static Future<JeepneyPathfinder> createAsync({
  required List<JeepneyRoute> routes,
  List<Map<String, dynamic>>? landmarks,
  HybridRoutingConfig config = HybridRoutingConfig.defaultConfig,
}) async {
  final params = _GraphBuildParams(routes, landmarks, config);
  final graph = await compute(_buildGraphInIsolate, params);

  final pathfinder = JeepneyPathfinder._internal(config: config);
  pathfinder._graph = graph;
  pathfinder._isInitialized = true;

  return pathfinder;
}
```

**Expected Impact:** **True background processing**, main thread never blocks

---

## Performance Metrics After Optimizations

| Metric                  | Before          | After (Estimated)         |
| ----------------------- | --------------- | ------------------------- |
| First route calculation | 9 seconds       | 9 seconds (one-time cost) |
| Subsequent calculations | 9 seconds       | **< 1 second**            |
| API load time           | 1-3 seconds     | **0ms (cached)**          |
| Main thread blocking    | Yes (45 frames) | **No blocking**           |
| App responsiveness      | Poor            | **Excellent**             |

---

## Implementation Priority

1. **Graph Caching** - Immediate 8s improvement on 2nd+ calculations
2. **API Local Cache** - 1-3s improvement on app restarts
3. **Spatial Indexing** - 2-3s improvement on graph build
4. **True Isolates** - Eliminates UI freezing
5. **API Compression** - 50-70% faster network transfer
6. **Lazy Loading** - 50-70% smaller initial load

---

## Quick Win: Graph Caching Implementation

Add this to `HybridTransitRouter`:

```dart
// Add to class
DateTime? _lastGraphBuild;
static const _cacheValidDuration = Duration(hours: 1);

// Modify preInitialize
Future<void> preInitialize({
  required List<JeepneyRoute> routes,
  List<Map<String, dynamic>>? landmarks,
}) async {
  final routesChanged = /* existing check */;

  // NEW: Check cache validity
  if (_pathfinder != null &&
      _lastGraphBuild != null &&
      !routesChanged &&
      DateTime.now().difference(_lastGraphBuild!) < _cacheValidDuration) {
    debugPrint('[HybridRouter] Graph cache valid, skipping rebuild');
    return;
  }

  // Build graph
  debugPrint('[HybridRouter] Building graph...');
  _pathfinder = await JeepneyPathfinder.createAsync(/*...*/);
  _lastGraphBuild = DateTime.now();
  _cachedRoutes = routes;
  _cachedLandmarks = landmarks;
  debugPrint('[HybridRouter] Graph cached successfully');
}
```

This single change will make your **2nd, 3rd, 4th... route calculations instant** instead of 9 seconds each!
