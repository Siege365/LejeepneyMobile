import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../../models/jeepney_route.dart';
import 'geo_utils.dart';
import 'models.dart';
import 'transit_graph.dart';

// Parameters for isolate graph building
class _GraphBuildParams {
  final List<JeepneyRoute> routes;
  final List<Map<String, dynamic>>? landmarks;
  final HybridRoutingConfig config;

  _GraphBuildParams(this.routes, this.landmarks, this.config);
}

/// Finds transit routes using only jeepney route data (no OSRM dependency)
/// This is the fallback pathfinder when OSRM paths have poor jeepney coverage
class JeepneyPathfinder {
  final HybridRoutingConfig config;
  late final TransitGraph _graph;
  bool _isInitialized = false;

  JeepneyPathfinder({
    required List<JeepneyRoute> routes,
    List<Map<String, dynamic>>? landmarks,
    this.config = HybridRoutingConfig.defaultConfig,
  }) {
    _graph = TransitGraph(routes: routes, landmarks: landmarks, config: config);
    // Build graph synchronously in constructor for backwards compatibility
    _graph.build();
    _isInitialized = true;
  }

  /// Check if the pathfinder is ready
  bool get isReady => _isInitialized;

  /// Build graph in background isolate (truly non-blocking)
  static TransitGraph _buildGraphInIsolate(_GraphBuildParams params) {
    final graph = TransitGraph(
      routes: params.routes,
      landmarks: params.landmarks,
      config: params.config,
    );
    graph.build(); // Runs in isolate - doesn't block main thread
    return graph;
  }

  /// Build the graph asynchronously in a background isolate (truly non-blocking)
  static Future<JeepneyPathfinder> createAsync({
    required List<JeepneyRoute> routes,
    List<Map<String, dynamic>>? landmarks,
    HybridRoutingConfig config = HybridRoutingConfig.defaultConfig,
  }) async {
    debugPrint(
      '[Pathfinder] Creating async pathfinder with ${routes.length} routes...',
    );
    final stopwatch = Stopwatch()..start();

    final pathfinder = JeepneyPathfinder._internal(config: config);

    // Build graph in background isolate - TRULY non-blocking
    final params = _GraphBuildParams(routes, landmarks, config);
    pathfinder._graph = await compute(_buildGraphInIsolate, params);
    pathfinder._isInitialized = true;

    stopwatch.stop();
    debugPrint(
      '[Pathfinder] Async initialization complete in ${stopwatch.elapsedMilliseconds}ms (background isolate)',
    );

    return pathfinder;
  }

  JeepneyPathfinder._internal({required this.config});

  /// Find suggested routes from origin to destination
  /// Returns up to maxResults route combinations
  List<SuggestedRoute> findRoutes({
    required LatLng origin,
    required LatLng destination,
    List<Map<String, dynamic>>? landmarks,
  }) {
    final results = <SuggestedRoute>[];
    final stopwatch = Stopwatch()..start();

    // Find routes accessible from origin
    final originRoutes = _graph.findRoutesNearPoint(
      origin,
      maxDistance: config.maxAccessWalkingMeters,
    );
    debugPrint(
      '[Pathfinder] Found ${originRoutes.length} routes near origin (max ${config.maxAccessWalkingMeters}m)',
    );

    // Find routes accessible from destination
    final destRoutes = _graph.findRoutesNearPoint(
      destination,
      maxDistance: config.maxAccessWalkingMeters,
    );
    debugPrint(
      '[Pathfinder] Found ${destRoutes.length} routes near destination',
    );

    if (originRoutes.isEmpty || destRoutes.isEmpty) {
      if (originRoutes.isEmpty) {
        debugPrint(
          '[Pathfinder] FAILED: No jeepney routes within ${config.maxAccessWalkingMeters}m of origin',
        );
      }
      if (destRoutes.isEmpty) {
        debugPrint(
          '[Pathfinder] FAILED: No jeepney routes within ${config.maxAccessWalkingMeters}m of destination',
        );
      }
      return results;
    }

    // Strategy 1: Direct routes (same route serves both points)
    final directRoutes = _findDirectRoutes(
      origin: origin,
      destination: destination,
      originRoutes: originRoutes,
      destRoutes: destRoutes,
      landmarks: landmarks,
    );
    results.addAll(directRoutes);
    debugPrint(
      '[Pathfinder] Strategy 1 (Direct): Found ${directRoutes.length} routes',
    );

    // Score and deduplicate after each strategy to check actual unique count
    var scoredResults = _scoreAndRank(results);
    debugPrint(
      '[Pathfinder] After deduplication: ${scoredResults.length} unique routes',
    );

    // Strategy 2: One transfer routes
    if (scoredResults.length < config.maxResults) {
      final oneTransferRoutes = _findOneTransferRoutes(
        origin: origin,
        destination: destination,
        originRoutes: originRoutes,
        destRoutes: destRoutes,
        landmarks: landmarks,
      );
      results.addAll(oneTransferRoutes);
      debugPrint(
        '[Pathfinder] Strategy 2 (1-Transfer): Found ${oneTransferRoutes.length} routes',
      );
      scoredResults = _scoreAndRank(results);
      debugPrint(
        '[Pathfinder] After deduplication: ${scoredResults.length} unique routes',
      );
    }

    // Strategy 3: Two transfer routes (only if needed)
    if (scoredResults.length < config.maxResults && config.maxTransfers >= 2) {
      final twoTransferRoutes = _findTwoTransferRoutes(
        origin: origin,
        destination: destination,
        originRoutes: originRoutes,
        destRoutes: destRoutes,
        landmarks: landmarks,
      );
      results.addAll(twoTransferRoutes);
      debugPrint(
        '[Pathfinder] Strategy 3 (2-Transfer): Found ${twoTransferRoutes.length} routes',
      );
      scoredResults = _scoreAndRank(results);
      debugPrint(
        '[Pathfinder] After deduplication: ${scoredResults.length} unique routes',
      );
    }

    // Final scoring already done above

    stopwatch.stop();
    debugPrint(
      '[Pathfinder] Total: ${scoredResults.length} routes found in ${stopwatch.elapsedMilliseconds}ms',
    );

    return scoredResults.take(config.maxResults).toList();
  }

  /// Find direct routes (no transfers needed)
  List<SuggestedRoute> _findDirectRoutes({
    required LatLng origin,
    required LatLng destination,
    required List<RouteAccess> originRoutes,
    required List<RouteAccess> destRoutes,
    List<Map<String, dynamic>>? landmarks,
  }) {
    final results = <SuggestedRoute>[];
    final processedRouteIds = <int>{}; // Track which routes we've already added

    // Find routes that appear in both lists
    for (final originAccess in originRoutes) {
      for (final destAccess in destRoutes) {
        if (originAccess.route.id == destAccess.route.id) {
          // Skip if we already processed this route (take first/best access point)
          if (processedRouteIds.contains(originAccess.route.id)) {
            continue;
          }
          processedRouteIds.add(originAccess.route.id);

          final route = originAccess.route;

          // Calculate journey segments
          final segments = <JourneySegment>[];
          double totalFare = 0;
          double totalDistance = 0;
          double totalWalking = 0;
          double totalTime = 0;

          // Walking to the route
          final walkToRoute = originAccess.walkingDistanceMeters / 1000;
          if (walkToRoute > 0.01) {
            segments.add(
              JourneySegment(
                startPoint: origin,
                endPoint: originAccess.accessPoint,
                startName: 'Your Location',
                endName:
                    _findLandmarkName(originAccess.accessPoint, landmarks) ??
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
          final rideDistance = GeoUtils.haversineDistance(
            originAccess.accessPoint,
            destAccess.accessPoint,
          );
          final rideFare = _calculateFare(route, rideDistance);

          segments.add(
            JourneySegment(
              route: route,
              startPoint: originAccess.accessPoint,
              endPoint: destAccess.accessPoint,
              startName: _findLandmarkName(originAccess.accessPoint, landmarks),
              endName: _findLandmarkName(destAccess.accessPoint, landmarks),
              type: JourneySegmentType.jeepneyRide,
              distanceKm: rideDistance,
              fare: rideFare,
              estimatedTimeMinutes: GeoUtils.estimateJeepneyTime(rideDistance),
              matchPercentage: 100.0, // Direct route from jeepney data
            ),
          );
          totalFare += rideFare;
          totalDistance += rideDistance;
          totalTime += GeoUtils.estimateJeepneyTime(rideDistance);

          // Walking from the route to destination
          final walkFromRoute = destAccess.walkingDistanceMeters / 1000;
          if (walkFromRoute > 0.01) {
            segments.add(
              JourneySegment(
                startPoint: destAccess.accessPoint,
                endPoint: destination,
                startName:
                    _findLandmarkName(destAccess.accessPoint, landmarks) ??
                    '${route.routeNumber} Stop',
                endName: 'Destination',
                type: JourneySegmentType.walking,
                distanceKm: walkFromRoute,
                fare: 0,
                estimatedTimeMinutes: GeoUtils.estimateWalkingTime(
                  walkFromRoute,
                ),
              ),
            );
            totalWalking += walkFromRoute;
            totalDistance += walkFromRoute;
            totalTime += GeoUtils.estimateWalkingTime(walkFromRoute);
          }

          results.add(
            SuggestedRoute(
              id: 'direct_${route.id}_${results.length}',
              segments: segments,
              totalFare: totalFare,
              totalDistanceKm: totalDistance,
              totalWalkingDistanceKm: totalWalking,
              estimatedTimeMinutes: totalTime,
              transferCount: 0,
              score: 0, // Will be calculated later
              sourceType: RouteSourceType.jeepneyBased,
            ),
          );
        }
      }
    }

    return results;
  }

  /// Find routes with one transfer
  List<SuggestedRoute> _findOneTransferRoutes({
    required LatLng origin,
    required LatLng destination,
    required List<RouteAccess> originRoutes,
    required List<RouteAccess> destRoutes,
    List<Map<String, dynamic>>? landmarks,
  }) {
    final results = <SuggestedRoute>[];
    final processedPairs = <String>{};

    for (final originAccess in originRoutes) {
      final originRoute = originAccess.route;

      // Find routes that intersect with the origin route
      final intersections = _graph.findRouteIntersections(originRoute);

      for (final intersection in intersections) {
        // Get the other route at this intersection
        final connectingRoute = intersection.route1.id == originRoute.id
            ? intersection.route2
            : intersection.route1;

        // Check if connecting route can reach destination
        final destAccess = destRoutes.firstWhere(
          (d) => d.route.id == connectingRoute.id,
          orElse: () => RouteAccess(
            route: connectingRoute,
            accessPoint: destination,
            walkingDistanceMeters: double.infinity,
            pointIndex: -1,
          ),
        );

        if (destAccess.walkingDistanceMeters > config.maxAccessWalkingMeters) {
          continue;
        }

        // Avoid duplicate pairs
        final pairKey = '${originRoute.id}_${connectingRoute.id}';
        if (processedPairs.contains(pairKey)) continue;
        processedPairs.add(pairKey);

        // Build the route
        final suggestedRoute = _buildTwoLegRoute(
          origin: origin,
          destination: destination,
          firstRoute: originRoute,
          secondRoute: connectingRoute,
          originAccess: originAccess,
          transferPoint: intersection.point,
          destAccess: destAccess,
          walkingDistance: intersection.distanceMeters,
          landmarks: landmarks,
        );

        if (suggestedRoute != null) {
          results.add(suggestedRoute);
        }
      }
    }

    return results;
  }

  /// Find routes with two transfers
  List<SuggestedRoute> _findTwoTransferRoutes({
    required LatLng origin,
    required LatLng destination,
    required List<RouteAccess> originRoutes,
    required List<RouteAccess> destRoutes,
    List<Map<String, dynamic>>? landmarks,
  }) {
    final results = <SuggestedRoute>[];
    final processedCombos = <String>{};

    for (final originAccess in originRoutes) {
      final route1 = originAccess.route;
      final route1Intersections = _graph.findRouteIntersections(route1);

      for (final intersection1 in route1Intersections) {
        final route2 = intersection1.route1.id == route1.id
            ? intersection1.route2
            : intersection1.route1;

        // Find what route2 connects to
        final route2Intersections = _graph.findRouteIntersections(route2);

        for (final intersection2 in route2Intersections) {
          final route3 = intersection2.route1.id == route2.id
              ? intersection2.route2
              : intersection2.route1;

          // Skip if route3 is same as route1
          if (route3.id == route1.id) continue;

          // Check if route3 can reach destination
          final destAccess = destRoutes.firstWhere(
            (d) => d.route.id == route3.id,
            orElse: () => RouteAccess(
              route: route3,
              accessPoint: destination,
              walkingDistanceMeters: double.infinity,
              pointIndex: -1,
            ),
          );

          if (destAccess.walkingDistanceMeters >
              config.maxAccessWalkingMeters) {
            continue;
          }

          // Avoid duplicates
          final comboKey = '${route1.id}_${route2.id}_${route3.id}';
          if (processedCombos.contains(comboKey)) continue;
          processedCombos.add(comboKey);

          // Build the three-leg route
          final suggestedRoute = _buildThreeLegRoute(
            origin: origin,
            destination: destination,
            route1: route1,
            route2: route2,
            route3: route3,
            originAccess: originAccess,
            transfer1Point: intersection1.point,
            transfer1Walking: intersection1.distanceMeters,
            transfer2Point: intersection2.point,
            transfer2Walking: intersection2.distanceMeters,
            destAccess: destAccess,
            landmarks: landmarks,
          );

          if (suggestedRoute != null) {
            results.add(suggestedRoute);
          }
        }
      }
    }

    return results;
  }

  /// Build a two-leg (one transfer) route
  SuggestedRoute? _buildTwoLegRoute({
    required LatLng origin,
    required LatLng destination,
    required JeepneyRoute firstRoute,
    required JeepneyRoute secondRoute,
    required RouteAccess originAccess,
    required LatLng transferPoint,
    required RouteAccess destAccess,
    required double walkingDistance,
    List<Map<String, dynamic>>? landmarks,
  }) {
    final segments = <JourneySegment>[];
    double totalFare = 0;
    double totalDistance = 0;
    double totalWalking = 0;
    double totalTime = 0;

    // Segment 1: Walk to first route
    final walkToFirst = originAccess.walkingDistanceMeters / 1000;
    if (walkToFirst > 0.01) {
      segments.add(
        JourneySegment(
          startPoint: origin,
          endPoint: originAccess.accessPoint,
          startName: 'Your Location',
          endName:
              _findLandmarkName(originAccess.accessPoint, landmarks) ??
              '${firstRoute.routeNumber} Stop',
          type: JourneySegmentType.walking,
          distanceKm: walkToFirst,
          fare: 0,
          estimatedTimeMinutes: GeoUtils.estimateWalkingTime(walkToFirst),
        ),
      );
      totalWalking += walkToFirst;
      totalDistance += walkToFirst;
      totalTime += GeoUtils.estimateWalkingTime(walkToFirst);
    }

    // Segment 2: First jeepney ride
    final firstRideDistance = GeoUtils.haversineDistance(
      originAccess.accessPoint,
      transferPoint,
    );
    final firstFare = _calculateFare(firstRoute, firstRideDistance);

    segments.add(
      JourneySegment(
        route: firstRoute,
        startPoint: originAccess.accessPoint,
        endPoint: transferPoint,
        startName: _findLandmarkName(originAccess.accessPoint, landmarks),
        endName:
            _findLandmarkName(transferPoint, landmarks) ?? 'Transfer Point',
        type: JourneySegmentType.jeepneyRide,
        distanceKm: firstRideDistance,
        fare: firstFare,
        estimatedTimeMinutes: GeoUtils.estimateJeepneyTime(firstRideDistance),
      ),
    );
    totalFare += firstFare;
    totalDistance += firstRideDistance;
    totalTime += GeoUtils.estimateJeepneyTime(firstRideDistance);

    // Segment 3: Transfer walk (if needed)
    final transferWalk = walkingDistance / 1000;
    if (transferWalk > 0.01) {
      segments.add(
        JourneySegment(
          startPoint: transferPoint,
          endPoint: transferPoint, // Same point, just conceptual transfer
          startName:
              _findLandmarkName(transferPoint, landmarks) ?? 'Transfer Point',
          endName: '${secondRoute.routeNumber} Stop',
          type: JourneySegmentType.transfer,
          distanceKm: transferWalk,
          fare: 0,
          estimatedTimeMinutes: GeoUtils.estimateWalkingTime(transferWalk),
        ),
      );
      totalWalking += transferWalk;
      totalDistance += transferWalk;
      totalTime += GeoUtils.estimateWalkingTime(transferWalk);
    }

    // Segment 4: Second jeepney ride
    final secondRideDistance = GeoUtils.haversineDistance(
      transferPoint,
      destAccess.accessPoint,
    );
    final secondFare = _calculateFare(secondRoute, secondRideDistance);

    segments.add(
      JourneySegment(
        route: secondRoute,
        startPoint: transferPoint,
        endPoint: destAccess.accessPoint,
        startName: _findLandmarkName(transferPoint, landmarks),
        endName: _findLandmarkName(destAccess.accessPoint, landmarks),
        type: JourneySegmentType.jeepneyRide,
        distanceKm: secondRideDistance,
        fare: secondFare,
        estimatedTimeMinutes: GeoUtils.estimateJeepneyTime(secondRideDistance),
      ),
    );
    totalFare += secondFare;
    totalDistance += secondRideDistance;
    totalTime += GeoUtils.estimateJeepneyTime(secondRideDistance);

    // Segment 5: Walk to destination
    final walkToDest = destAccess.walkingDistanceMeters / 1000;
    if (walkToDest > 0.01) {
      segments.add(
        JourneySegment(
          startPoint: destAccess.accessPoint,
          endPoint: destination,
          startName:
              _findLandmarkName(destAccess.accessPoint, landmarks) ??
              '${secondRoute.routeNumber} Stop',
          endName: 'Destination',
          type: JourneySegmentType.walking,
          distanceKm: walkToDest,
          fare: 0,
          estimatedTimeMinutes: GeoUtils.estimateWalkingTime(walkToDest),
        ),
      );
      totalWalking += walkToDest;
      totalDistance += walkToDest;
      totalTime += GeoUtils.estimateWalkingTime(walkToDest);
    }

    return SuggestedRoute(
      id: 'transfer1_${firstRoute.id}_${secondRoute.id}',
      segments: segments,
      totalFare: totalFare,
      totalDistanceKm: totalDistance,
      totalWalkingDistanceKm: totalWalking,
      estimatedTimeMinutes: totalTime,
      transferCount: 1,
      score: 0,
      sourceType: RouteSourceType.jeepneyBased,
    );
  }

  /// Build a three-leg (two transfer) route
  SuggestedRoute? _buildThreeLegRoute({
    required LatLng origin,
    required LatLng destination,
    required JeepneyRoute route1,
    required JeepneyRoute route2,
    required JeepneyRoute route3,
    required RouteAccess originAccess,
    required LatLng transfer1Point,
    required double transfer1Walking,
    required LatLng transfer2Point,
    required double transfer2Walking,
    required RouteAccess destAccess,
    List<Map<String, dynamic>>? landmarks,
  }) {
    final segments = <JourneySegment>[];
    double totalFare = 0;
    double totalDistance = 0;
    double totalWalking = 0;
    double totalTime = 0;

    // Walk to first route
    final walkToFirst = originAccess.walkingDistanceMeters / 1000;
    if (walkToFirst > 0.01) {
      segments.add(
        JourneySegment(
          startPoint: origin,
          endPoint: originAccess.accessPoint,
          startName: 'Your Location',
          endName: '${route1.routeNumber} Stop',
          type: JourneySegmentType.walking,
          distanceKm: walkToFirst,
          fare: 0,
          estimatedTimeMinutes: GeoUtils.estimateWalkingTime(walkToFirst),
        ),
      );
      totalWalking += walkToFirst;
      totalDistance += walkToFirst;
      totalTime += GeoUtils.estimateWalkingTime(walkToFirst);
    }

    // First ride
    final ride1Distance = GeoUtils.haversineDistance(
      originAccess.accessPoint,
      transfer1Point,
    );
    final fare1 = _calculateFare(route1, ride1Distance);
    segments.add(
      JourneySegment(
        route: route1,
        startPoint: originAccess.accessPoint,
        endPoint: transfer1Point,
        startName: _findLandmarkName(originAccess.accessPoint, landmarks),
        endName: _findLandmarkName(transfer1Point, landmarks) ?? 'Transfer 1',
        type: JourneySegmentType.jeepneyRide,
        distanceKm: ride1Distance,
        fare: fare1,
        estimatedTimeMinutes: GeoUtils.estimateJeepneyTime(ride1Distance),
      ),
    );
    totalFare += fare1;
    totalDistance += ride1Distance;
    totalTime += GeoUtils.estimateJeepneyTime(ride1Distance);

    // Transfer 1
    final transfer1Walk = transfer1Walking / 1000;
    if (transfer1Walk > 0.01) {
      segments.add(
        JourneySegment(
          startPoint: transfer1Point,
          endPoint: transfer1Point,
          startName:
              _findLandmarkName(transfer1Point, landmarks) ?? 'Transfer 1',
          endName: '${route2.routeNumber} Stop',
          type: JourneySegmentType.transfer,
          distanceKm: transfer1Walk,
          fare: 0,
          estimatedTimeMinutes: GeoUtils.estimateWalkingTime(transfer1Walk),
        ),
      );
      totalWalking += transfer1Walk;
      totalDistance += transfer1Walk;
      totalTime += GeoUtils.estimateWalkingTime(transfer1Walk);
    }

    // Second ride
    final ride2Distance = GeoUtils.haversineDistance(
      transfer1Point,
      transfer2Point,
    );
    final fare2 = _calculateFare(route2, ride2Distance);
    segments.add(
      JourneySegment(
        route: route2,
        startPoint: transfer1Point,
        endPoint: transfer2Point,
        startName: _findLandmarkName(transfer1Point, landmarks),
        endName: _findLandmarkName(transfer2Point, landmarks) ?? 'Transfer 2',
        type: JourneySegmentType.jeepneyRide,
        distanceKm: ride2Distance,
        fare: fare2,
        estimatedTimeMinutes: GeoUtils.estimateJeepneyTime(ride2Distance),
      ),
    );
    totalFare += fare2;
    totalDistance += ride2Distance;
    totalTime += GeoUtils.estimateJeepneyTime(ride2Distance);

    // Transfer 2
    final transfer2Walk = transfer2Walking / 1000;
    if (transfer2Walk > 0.01) {
      segments.add(
        JourneySegment(
          startPoint: transfer2Point,
          endPoint: transfer2Point,
          startName:
              _findLandmarkName(transfer2Point, landmarks) ?? 'Transfer 2',
          endName: '${route3.routeNumber} Stop',
          type: JourneySegmentType.transfer,
          distanceKm: transfer2Walk,
          fare: 0,
          estimatedTimeMinutes: GeoUtils.estimateWalkingTime(transfer2Walk),
        ),
      );
      totalWalking += transfer2Walk;
      totalDistance += transfer2Walk;
      totalTime += GeoUtils.estimateWalkingTime(transfer2Walk);
    }

    // Third ride
    final ride3Distance = GeoUtils.haversineDistance(
      transfer2Point,
      destAccess.accessPoint,
    );
    final fare3 = _calculateFare(route3, ride3Distance);
    segments.add(
      JourneySegment(
        route: route3,
        startPoint: transfer2Point,
        endPoint: destAccess.accessPoint,
        startName: _findLandmarkName(transfer2Point, landmarks),
        endName: _findLandmarkName(destAccess.accessPoint, landmarks),
        type: JourneySegmentType.jeepneyRide,
        distanceKm: ride3Distance,
        fare: fare3,
        estimatedTimeMinutes: GeoUtils.estimateJeepneyTime(ride3Distance),
      ),
    );
    totalFare += fare3;
    totalDistance += ride3Distance;
    totalTime += GeoUtils.estimateJeepneyTime(ride3Distance);

    // Walk to destination
    final walkToDest = destAccess.walkingDistanceMeters / 1000;
    if (walkToDest > 0.01) {
      segments.add(
        JourneySegment(
          startPoint: destAccess.accessPoint,
          endPoint: destination,
          startName: '${route3.routeNumber} Stop',
          endName: 'Destination',
          type: JourneySegmentType.walking,
          distanceKm: walkToDest,
          fare: 0,
          estimatedTimeMinutes: GeoUtils.estimateWalkingTime(walkToDest),
        ),
      );
      totalWalking += walkToDest;
      totalDistance += walkToDest;
      totalTime += GeoUtils.estimateWalkingTime(walkToDest);
    }

    return SuggestedRoute(
      id: 'transfer2_${route1.id}_${route2.id}_${route3.id}',
      segments: segments,
      totalFare: totalFare,
      totalDistanceKm: totalDistance,
      totalWalkingDistanceKm: totalWalking,
      estimatedTimeMinutes: totalTime,
      transferCount: 2,
      score: 0,
      sourceType: RouteSourceType.jeepneyBased,
    );
  }

  /// Calculate fare for a route segment
  /// Uses standard jeepney fare structure: base fare for first 4km, then ₱1.50/km
  static const double _defaultPerKmRate = 1.50;
  static const double _baseFareDistance = 4.0;

  double _calculateFare(JeepneyRoute route, double distanceKm) {
    // Use base fare + distance-based additional fare
    // Default: base fare covers first 4km, then additional per km
    if (distanceKm <= _baseFareDistance) {
      return route.baseFare;
    }

    final additionalKm = distanceKm - _baseFareDistance;
    final additionalFare = additionalKm * _defaultPerKmRate;

    return route.baseFare + additionalFare;
  }

  /// Find landmark name for a point
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

  /// Score and rank routes
  List<SuggestedRoute> _scoreAndRank(List<SuggestedRoute> routes) {
    final scored = <SuggestedRoute>[];

    for (final route in routes) {
      // Scoring formula (lower is better):
      // - Transfer penalty: 40 points per transfer
      // - Fare weight: 2 points per peso
      // - Walking penalty: 0.1 points per meter walking
      // - Time weight: 1 point per minute
      // - Distance bonus: -5 for shorter routes

      final score =
          (route.transferCount * 40.0) +
          (route.totalFare * 2.0) +
          (route.totalWalkingDistanceKm * 100) + // 0.1 * 1000m = 100 per km
          (route.estimatedTimeMinutes * 1.0) -
          (route.totalDistanceKm < 5 ? 5 : 0);

      scored.add(
        SuggestedRoute(
          id: route.id,
          segments: route.segments,
          totalFare: route.totalFare,
          totalDistanceKm: route.totalDistanceKm,
          totalWalkingDistanceKm: route.totalWalkingDistanceKm,
          estimatedTimeMinutes: route.estimatedTimeMinutes,
          transferCount: route.transferCount,
          score: score,
          sourceType: route.sourceType,
          osrmMatchPercentage: route.osrmMatchPercentage,
        ),
      );
    }

    // Sort by score (lowest first)
    scored.sort((a, b) => a.score.compareTo(b.score));

    // Remove duplicates (same route combination with similar metrics)
    final seen = <String>{};
    final unique = <SuggestedRoute>[];

    for (final route in scored) {
      // More permissive key to allow variations
      // Include fare and walking distance to allow different route variants
      final key =
          '${route.routeNames}_${route.transferCount}_${route.totalFare.toStringAsFixed(0)}_${(route.totalWalkingDistanceKm * 1000).toStringAsFixed(0)}';
      if (!seen.contains(key)) {
        seen.add(key);
        unique.add(route);
      }
    }

    return unique;
  }
}
