import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../../models/jeepney_route.dart';
import 'geo_utils.dart';
import 'jeepney_pathfinder.dart';
import 'models.dart';
import 'route_validator.dart';

/// Main hybrid transit router that combines OSRM validation with jeepney-based pathfinding
/// Automatically falls back to jeepney-based routing when OSRM paths have poor coverage
class HybridTransitRouter {
  final HybridRoutingConfig config;
  final RouteAccuracyValidator _validator;

  // Cached pathfinder (rebuilt when routes change)
  JeepneyPathfinder? _pathfinder;
  List<JeepneyRoute>? _cachedRoutes;
  // ignore: unused_field - Reserved for landmark-based routing
  List<Map<String, dynamic>>? _cachedLandmarks;
  DateTime? _lastGraphBuild;
  static const _graphCacheValidDuration = Duration(hours: 1);

  HybridTransitRouter({this.config = HybridRoutingConfig.defaultConfig})
    : _validator = RouteAccuracyValidator(config: config);

  /// Find suggested routes from origin to destination
  /// Uses hybrid approach: validates OSRM first, falls back to jeepney-based if needed
  Future<HybridRoutingResult> findRoutes({
    required LatLng origin,
    required LatLng destination,
    required List<JeepneyRoute> jeepneyRoutes,
    List<LatLng>? osrmPath,
    List<Map<String, dynamic>>? landmarks,
  }) async {
    final stopwatch = Stopwatch()..start();
    debugPrint(
      '[HybridRouter] Finding routes from ${origin.latitude.toStringAsFixed(4)},${origin.longitude.toStringAsFixed(4)} to ${destination.latitude.toStringAsFixed(4)},${destination.longitude.toStringAsFixed(4)}',
    );
    debugPrint(
      '[HybridRouter] Available jeepney routes: ${jeepneyRoutes.length}, OSRM path points: ${osrmPath?.length ?? 0}',
    );

    // Update pathfinder cache if routes changed
    _updatePathfinderCache(jeepneyRoutes, landmarks);

    // Validate OSRM path if provided
    RouteValidationResult? validationResult;
    List<SuggestedRoute> osrmBasedRoutes = [];

    if (osrmPath != null && osrmPath.isNotEmpty) {
      validationResult = _validator.validate(
        osrmPath: osrmPath,
        jeepneyRoutes: jeepneyRoutes,
      );

      debugPrint('OSRM Validation: ${validationResult.reason}');

      // If OSRM path is accurate, try to match it to jeepney routes
      if (validationResult.isAccurate) {
        osrmBasedRoutes = _matchOsrmToJeepney(
          osrmPath: osrmPath,
          origin: origin,
          destination: destination,
          jeepneyRoutes: jeepneyRoutes,
          landmarks: landmarks,
        );
        debugPrint(
          '[HybridRouter] OSRM-based routes found: ${osrmBasedRoutes.length}',
        );
      }
    } else {
      debugPrint(
        '[HybridRouter] No OSRM path provided, using jeepney-based routing only',
      );
    }

    // Find jeepney-based routes (always as alternative or primary)
    List<SuggestedRoute> jeepneyBasedRoutes = [];
    if (_pathfinder != null) {
      jeepneyBasedRoutes = _pathfinder!.findRoutes(
        origin: origin,
        destination: destination,
        landmarks: landmarks,
      );
      debugPrint(
        '[HybridRouter] Jeepney-based routes found: ${jeepneyBasedRoutes.length}',
      );
    } else {
      debugPrint(
        '[HybridRouter] WARNING: Pathfinder is null, cannot find jeepney-based routes',
      );
    }

    // Determine primary source and combine results
    final RouteSourceType primarySource;
    List<SuggestedRoute> combinedRoutes;

    if (validationResult != null &&
        validationResult.isAccurate &&
        osrmBasedRoutes.isNotEmpty) {
      // OSRM is accurate - use it as primary, add jeepney-based as alternatives
      primarySource = RouteSourceType.osrmValidated;
      combinedRoutes = _mergeAndRank([
        ...osrmBasedRoutes,
        ...jeepneyBasedRoutes,
      ]);
    } else if (jeepneyBasedRoutes.isNotEmpty) {
      // OSRM failed or inaccurate - use jeepney-based as primary
      primarySource = RouteSourceType.jeepneyBased;
      combinedRoutes = _mergeAndRank([
        ...jeepneyBasedRoutes,
        ...osrmBasedRoutes,
      ]);
    } else {
      // No routes found
      primarySource = RouteSourceType.jeepneyBased;
      combinedRoutes = [];
      debugPrint('[HybridRouter] WARNING: No routes found from any source!');
    }

    stopwatch.stop();
    final finalRoutes = combinedRoutes.take(config.maxResults).toList();
    debugPrint(
      '[HybridRouter] Final result: ${finalRoutes.length} routes, source: ${primarySource.name}, took ${stopwatch.elapsedMilliseconds}ms',
    );

    return HybridRoutingResult(
      suggestedRoutes: finalRoutes,
      primarySource: primarySource,
      osrmValidation: validationResult,
      fallbackUsed: validationResult != null && !validationResult.isAccurate,
      osrmBasedCount: osrmBasedRoutes.length,
      jeepneyBasedCount: jeepneyBasedRoutes.length,
    );
  }

  /// Update pathfinder cache if routes changed
  /// NOTE: This should NOT be called during route calculations - use preInitialize() instead!
  /// This method is only kept for edge cases where async initialization wasn't done.
  void _updatePathfinderCache(
    List<JeepneyRoute> routes,
    List<Map<String, dynamic>>? landmarks,
  ) {
    final routesChanged =
        _cachedRoutes == null ||
        _cachedRoutes!.length != routes.length ||
        (routes.isNotEmpty && _cachedRoutes!.first.id != routes.first.id);

    if (routesChanged && _pathfinder == null) {
      debugPrint(
        '[HybridRouter] WARNING: Pathfinder not pre-initialized! Building synchronously (slow)...',
      );
      debugPrint(
        '[HybridRouter] TIP: Call preInitialize() when routes are loaded to avoid main thread blocking',
      );
      _pathfinder = JeepneyPathfinder(
        routes: routes,
        landmarks: landmarks,
        config: config,
      );
      _cachedRoutes = routes;
      _cachedLandmarks = landmarks;
    } else if (routesChanged && _pathfinder != null) {
      debugPrint(
        '[HybridRouter] Routes changed but pathfinder exists - using existing cache',
      );
    }
  }

  /// Pre-initialize the pathfinder asynchronously (call when routes are first loaded)
  /// This allows the graph to be built in the background before user requests directions
  Future<void> preInitialize({
    required List<JeepneyRoute> routes,
    List<Map<String, dynamic>>? landmarks,
  }) async {
    final routesChanged =
        _cachedRoutes == null ||
        _cachedRoutes!.length != routes.length ||
        (routes.isNotEmpty && _cachedRoutes!.first.id != routes.first.id);

    // Check if cached graph is still valid
    if (_pathfinder != null &&
        _lastGraphBuild != null &&
        !routesChanged &&
        DateTime.now().difference(_lastGraphBuild!) <
            _graphCacheValidDuration) {
      final cacheAge = DateTime.now().difference(_lastGraphBuild!);
      debugPrint(
        '[HybridRouter] Using cached graph (age: ${cacheAge.inMinutes}min, valid for ${_graphCacheValidDuration.inMinutes}min)',
      );
      return;
    }

    if (routesChanged || _pathfinder == null) {
      debugPrint(
        '[HybridRouter] Pre-initializing pathfinder with ${routes.length} routes...',
      );
      final buildStopwatch = Stopwatch()..start();

      _pathfinder = await JeepneyPathfinder.createAsync(
        routes: routes,
        landmarks: landmarks,
        config: config,
      );

      _cachedRoutes = routes;
      _cachedLandmarks = landmarks;
      _lastGraphBuild = DateTime.now();

      buildStopwatch.stop();
      debugPrint(
        '[HybridRouter] Pre-initialization complete in ${buildStopwatch.elapsedMilliseconds}ms, cached at ${_lastGraphBuild}',
      );
    }
  }

  /// Check if pathfinder is ready
  bool get isReady => _pathfinder?.isReady ?? false;

  /// Match OSRM path to jeepney routes (creates SuggestedRoute objects)
  List<SuggestedRoute> _matchOsrmToJeepney({
    required List<LatLng> osrmPath,
    required LatLng origin,
    required LatLng destination,
    required List<JeepneyRoute> jeepneyRoutes,
    List<Map<String, dynamic>>? landmarks,
  }) {
    final results = <SuggestedRoute>[];

    // Get detailed coverage analysis
    final analysis = _validator.getDetailedCoverageAnalysis(
      path: osrmPath,
      routes: jeepneyRoutes,
    );

    final routeCoverage = analysis['routeCoverage'] as Map<String, double>;

    // Create suggested routes for well-matching jeepney routes
    for (final entry in routeCoverage.entries) {
      if (entry.value < 40) continue; // Skip low coverage routes

      final route = jeepneyRoutes.firstWhere(
        (r) => r.id.toString() == entry.key,
        orElse: () => jeepneyRoutes.first,
      );

      // Calculate access points
      final originAccess = GeoUtils.findClosestPointOnPath(origin, route.path);
      final destAccess = GeoUtils.findClosestPointOnPath(
        destination,
        route.path,
      );

      final walkToRoute = GeoUtils.distanceMeters(origin, originAccess) / 1000;
      final walkFromRoute =
          GeoUtils.distanceMeters(destAccess, destination) / 1000;
      final rideDistance = GeoUtils.haversineDistance(originAccess, destAccess);

      final segments = <JourneySegment>[];
      double totalFare = 0;
      double totalDistance = 0;
      double totalWalking = 0;
      double totalTime = 0;

      // Walk to route
      if (walkToRoute > 0.01) {
        segments.add(
          JourneySegment(
            startPoint: origin,
            endPoint: originAccess,
            startName: 'Your Location',
            endName:
                _findLandmarkName(originAccess, landmarks) ??
                '${route.routeNumber} Stop',
            type: JourneySegmentType.walking,
            distanceKm: walkToRoute,
            fare: 0,
            estimatedTimeMinutes: GeoUtils.estimateWalkingTime(walkToRoute),
          ),
        );
        totalWalking += walkToRoute;
        totalDistance += walkToRoute;
        totalTime += GeoUtils.estimateWalkingTime(walkToRoute);
      }

      // Jeepney ride
      final fare = _calculateFare(route, rideDistance);
      segments.add(
        JourneySegment(
          route: route,
          startPoint: originAccess,
          endPoint: destAccess,
          startName: _findLandmarkName(originAccess, landmarks),
          endName: _findLandmarkName(destAccess, landmarks),
          type: JourneySegmentType.jeepneyRide,
          distanceKm: rideDistance,
          fare: fare,
          estimatedTimeMinutes: GeoUtils.estimateJeepneyTime(rideDistance),
          matchPercentage: entry.value,
        ),
      );
      totalFare += fare;
      totalDistance += rideDistance;
      totalTime += GeoUtils.estimateJeepneyTime(rideDistance);

      // Walk from route
      if (walkFromRoute > 0.01) {
        segments.add(
          JourneySegment(
            startPoint: destAccess,
            endPoint: destination,
            startName:
                _findLandmarkName(destAccess, landmarks) ??
                '${route.routeNumber} Stop',
            endName: 'Destination',
            type: JourneySegmentType.walking,
            distanceKm: walkFromRoute,
            fare: 0,
            estimatedTimeMinutes: GeoUtils.estimateWalkingTime(walkFromRoute),
          ),
        );
        totalWalking += walkFromRoute;
        totalDistance += walkFromRoute;
        totalTime += GeoUtils.estimateWalkingTime(walkFromRoute);
      }

      // Calculate score
      final score =
          (totalFare * 2.0) +
          (totalWalking * 100) +
          (totalTime * 1.0) +
          (100 - entry.value); // Bonus for higher match

      results.add(
        SuggestedRoute(
          id: 'osrm_${route.id}',
          segments: segments,
          totalFare: totalFare,
          totalDistanceKm: totalDistance,
          totalWalkingDistanceKm: totalWalking,
          estimatedTimeMinutes: totalTime,
          transferCount: 0,
          score: score,
          sourceType: RouteSourceType.osrmValidated,
          osrmMatchPercentage: entry.value,
        ),
      );
    }

    return results;
  }

  /// Merge and rank routes from different sources
  List<SuggestedRoute> _mergeAndRank(List<SuggestedRoute> routes) {
    // Remove exact duplicates - but allow variations in fare/distance/walking
    final seen = <String>{};
    final unique = <SuggestedRoute>[];

    for (final route in routes) {
      // More permissive key: include fare and walking distance for variation
      // This allows multiple routes with same name but different segments/costs
      final key =
          '${route.routeNames}_${route.transferCount}_${route.totalFare.toStringAsFixed(0)}_${(route.totalWalkingDistanceKm * 1000).toStringAsFixed(0)}';
      if (!seen.contains(key)) {
        seen.add(key);
        unique.add(route);
      }
    }

    // Sort by score
    unique.sort((a, b) => a.score.compareTo(b.score));

    debugPrint(
      '[HybridRouter] Merged ${routes.length} routes -> ${unique.length} unique routes',
    );

    return unique;
  }

  /// Calculate fare for a route
  /// Uses standard jeepney fare structure: base fare for first 4km, then ₱1.50/km
  static const double _defaultPerKmRate = 1.50;
  static const double _baseFareDistance = 4.0;

  double _calculateFare(JeepneyRoute route, double distanceKm) {
    if (distanceKm <= _baseFareDistance) {
      return route.baseFare;
    }
    final additionalKm = distanceKm - _baseFareDistance;
    return route.baseFare + (additionalKm * _defaultPerKmRate);
  }

  /// Find landmark name near a point
  String? _findLandmarkName(
    LatLng point,
    List<Map<String, dynamic>>? landmarks,
  ) {
    if (landmarks == null || landmarks.isEmpty) return null;

    const maxDistance = 150.0;
    String? nearestName;
    double nearestDistance = double.infinity;

    for (final landmark in landmarks) {
      final lat = landmark['latitude'] as double?;
      final lng = landmark['longitude'] as double?;
      final name = landmark['name'] as String?;

      if (lat == null || lng == null || name == null) continue;

      final distance = GeoUtils.distanceMeters(point, LatLng(lat, lng));
      if (distance < nearestDistance && distance <= maxDistance) {
        nearestDistance = distance;
        nearestName = name;
      }
    }

    return nearestName;
  }

  /// Clear the pathfinder cache (call when routes are updated)
  void clearCache() {
    _pathfinder = null;
    _cachedRoutes = null;
    _cachedLandmarks = null;
  }
}

/// Result of hybrid routing
class HybridRoutingResult {
  final List<SuggestedRoute> suggestedRoutes;
  final RouteSourceType primarySource;
  final RouteValidationResult? osrmValidation;
  final bool fallbackUsed;
  final int osrmBasedCount;
  final int jeepneyBasedCount;

  HybridRoutingResult({
    required this.suggestedRoutes,
    required this.primarySource,
    this.osrmValidation,
    required this.fallbackUsed,
    required this.osrmBasedCount,
    required this.jeepneyBasedCount,
  });

  bool get hasRoutes => suggestedRoutes.isNotEmpty;
  int get totalRoutes => suggestedRoutes.length;

  /// Get the best suggested route
  SuggestedRoute? get bestRoute =>
      suggestedRoutes.isNotEmpty ? suggestedRoutes.first : null;

  @override
  String toString() {
    return 'HybridRoutingResult(${suggestedRoutes.length} routes, '
        'primary: ${primarySource.name}, fallback: $fallbackUsed)';
  }
}
