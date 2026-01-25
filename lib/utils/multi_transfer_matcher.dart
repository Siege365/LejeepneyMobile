import 'dart:math';
import 'package:latlong2/latlong.dart';
import '../models/jeepney_route.dart';
import 'route_matcher.dart';

/// Represents a transfer point between two jeepney routes
class TransferPoint {
  final LatLng location;
  final String? landmarkName;
  final int? landmarkId;
  final double walkingDistanceMeters;
  final JeepneyRoute fromRoute;
  final JeepneyRoute toRoute;

  TransferPoint({
    required this.location,
    this.landmarkName,
    this.landmarkId,
    required this.walkingDistanceMeters,
    required this.fromRoute,
    required this.toRoute,
  });

  @override
  String toString() =>
      'TransferPoint(${landmarkName ?? 'Unknown'}, walk: ${walkingDistanceMeters.toStringAsFixed(0)}m)';
}

/// A route segment using a single jeepney route
class RouteSegment {
  final JeepneyRoute route;
  final LatLng startPoint;
  final LatLng endPoint;
  final double distanceKm;
  final double fare;
  final double matchPercentage;

  RouteSegment({
    required this.route,
    required this.startPoint,
    required this.endPoint,
    required this.distanceKm,
    required this.fare,
    required this.matchPercentage,
  });
}

/// Complete multi-transfer route solution
class MultiTransferRoute {
  final List<RouteSegment> segments;
  final List<TransferPoint> transferPoints;
  final double totalFare;
  final double totalDistanceKm;
  final double totalWalkingDistanceMeters;
  final int transferCount;
  final double score; // Lower is better

  MultiTransferRoute({
    required this.segments,
    required this.transferPoints,
    required this.totalFare,
    required this.totalDistanceKm,
    required this.totalWalkingDistanceMeters,
    required this.transferCount,
    required this.score,
  });

  /// Display string for the route combination
  String get routeNames => segments.map((s) => s.route.routeNumber).join(' → ');

  /// Display string for transfer points
  String get transferPointNames =>
      transferPoints.map((t) => t.landmarkName ?? 'Transfer Point').join(', ');

  @override
  String toString() =>
      'MultiTransferRoute($routeNames, ${transferCount} transfers, ₱${totalFare.toStringAsFixed(2)})';
}

/// Utility class for finding multi-transfer route combinations
class MultiTransferMatcher {
  // Maximum walking distance between transfers (in meters)
  static const double maxWalkingDistance = 300.0;

  // Maximum number of transfers to consider
  static const int maxTransfers = 2;

  // Buffer distance for route matching (meters)
  static const double bufferMeters = 150.0;

  // Earth radius in km
  static const double _earthRadiusKm = 6371.0;

  /// Find multi-transfer routes when no direct route is available
  /// Returns sorted list of route combinations (best first)
  static List<MultiTransferRoute> findMultiTransferRoutes({
    required List<LatLng> userPath,
    required List<JeepneyRoute> jeepneyRoutes,
    List<Map<String, dynamic>>? landmarks,
    int maxResults = 5,
  }) {
    if (userPath.length < 2) return [];

    final results = <MultiTransferRoute>[];

    // Try 2-segment (1 transfer) routes first
    final twoSegmentRoutes = _findTwoSegmentRoutes(
      userPath: userPath,
      jeepneyRoutes: jeepneyRoutes,
      landmarks: landmarks,
    );
    results.addAll(twoSegmentRoutes);

    // Try 3-segment (2 transfers) routes if needed
    if (results.length < maxResults) {
      final threeSegmentRoutes = _findThreeSegmentRoutes(
        userPath: userPath,
        jeepneyRoutes: jeepneyRoutes,
        landmarks: landmarks,
      );
      results.addAll(threeSegmentRoutes);
    }

    // Score and sort results
    results.sort((a, b) => a.score.compareTo(b.score));

    return results.take(maxResults).toList();
  }

  /// Find routes requiring exactly 1 transfer (2 jeepney rides)
  static List<MultiTransferRoute> _findTwoSegmentRoutes({
    required List<LatLng> userPath,
    required List<JeepneyRoute> jeepneyRoutes,
    List<Map<String, dynamic>>? landmarks,
  }) {
    final results = <MultiTransferRoute>[];
    final startPoint = userPath.first;
    final endPoint = userPath.last;

    // Find route intersections
    final intersections = _findRouteIntersections(jeepneyRoutes);

    // For each pair of intersecting routes
    for (final intersection in intersections) {
      final route1 = intersection['route1'] as JeepneyRoute;
      final route2 = intersection['route2'] as JeepneyRoute;
      final intersectionPoint = intersection['point'] as LatLng;
      final walkingDistance = intersection['distance'] as double;

      // Skip if walking distance too far
      if (walkingDistance > maxWalkingDistance) continue;

      // Check if route1 can get us from start to intersection
      final route1CoversStart = _routeCoversPoint(
        route1,
        startPoint,
        bufferMeters,
      );
      final route1CoversIntersection = _routeCoversPoint(
        route1,
        intersectionPoint,
        bufferMeters,
      );

      // Check if route2 can get us from intersection to end
      final route2CoversIntersection = _routeCoversPoint(
        route2,
        intersectionPoint,
        bufferMeters,
      );
      final route2CoversEnd = _routeCoversPoint(route2, endPoint, bufferMeters);

      // Valid combination: Start→Route1→Transfer→Route2→End
      if (route1CoversStart &&
          route1CoversIntersection &&
          route2CoversIntersection &&
          route2CoversEnd) {
        final multiRoute = _buildMultiTransferRoute(
          segments: [route1, route2],
          transferPoints: [intersectionPoint],
          walkingDistances: [walkingDistance],
          startPoint: startPoint,
          endPoint: endPoint,
          landmarks: landmarks,
        );
        if (multiRoute != null) {
          results.add(multiRoute);
        }
      }

      // Also try reverse: Start→Route2→Transfer→Route1→End
      final route2CoversStart = _routeCoversPoint(
        route2,
        startPoint,
        bufferMeters,
      );
      final route1CoversEnd = _routeCoversPoint(route1, endPoint, bufferMeters);

      if (route2CoversStart &&
          route2CoversIntersection &&
          route1CoversIntersection &&
          route1CoversEnd) {
        final multiRoute = _buildMultiTransferRoute(
          segments: [route2, route1],
          transferPoints: [intersectionPoint],
          walkingDistances: [walkingDistance],
          startPoint: startPoint,
          endPoint: endPoint,
          landmarks: landmarks,
        );
        if (multiRoute != null) {
          results.add(multiRoute);
        }
      }
    }

    // Also try splitting path at midpoint
    final midPointRoutes = _findMidpointTransferRoutes(
      userPath: userPath,
      jeepneyRoutes: jeepneyRoutes,
      landmarks: landmarks,
    );
    results.addAll(midPointRoutes);

    return results;
  }

  /// Find routes by splitting user path at midpoint
  static List<MultiTransferRoute> _findMidpointTransferRoutes({
    required List<LatLng> userPath,
    required List<JeepneyRoute> jeepneyRoutes,
    List<Map<String, dynamic>>? landmarks,
  }) {
    final results = <MultiTransferRoute>[];
    if (userPath.length < 3) return results;

    // Split path at various points (25%, 50%, 75%)
    final splitPoints = [0.25, 0.5, 0.75];

    for (final splitRatio in splitPoints) {
      final splitIndex = (userPath.length * splitRatio).floor();
      final firstHalf = userPath.sublist(0, splitIndex + 1);
      final secondHalf = userPath.sublist(splitIndex);

      if (firstHalf.length < 2 || secondHalf.length < 2) continue;

      // Find routes for first segment
      final firstSegmentMatches = RouteMatcher.findMatchingRoutes(
        userPath: firstHalf,
        jeepneyRoutes: jeepneyRoutes,
        minMatchPercentage: 40.0,
        maxCount: 5,
      );

      // Find routes for second segment
      final secondSegmentMatches = RouteMatcher.findMatchingRoutes(
        userPath: secondHalf,
        jeepneyRoutes: jeepneyRoutes,
        minMatchPercentage: 40.0,
        maxCount: 5,
      );

      // Combine best matches
      for (final first in firstSegmentMatches) {
        for (final second in secondSegmentMatches) {
          // Skip if same route (already covered by direct matching)
          if (first.route.id == second.route.id) continue;

          // Calculate walking distance at transfer point
          final transferPoint = firstHalf.last;
          final walkingDist = _calculateWalkingDistanceToRoute(
            transferPoint,
            second.route.path,
          );

          if (walkingDist <= maxWalkingDistance) {
            final multiRoute = _buildMultiTransferRoute(
              segments: [first.route, second.route],
              transferPoints: [transferPoint],
              walkingDistances: [walkingDist],
              startPoint: userPath.first,
              endPoint: userPath.last,
              landmarks: landmarks,
              matchPercentages: [first.matchPercentage, second.matchPercentage],
            );
            if (multiRoute != null) {
              results.add(multiRoute);
            }
          }
        }
      }
    }

    return results;
  }

  /// Find routes requiring exactly 2 transfers (3 jeepney rides)
  static List<MultiTransferRoute> _findThreeSegmentRoutes({
    required List<LatLng> userPath,
    required List<JeepneyRoute> jeepneyRoutes,
    List<Map<String, dynamic>>? landmarks,
  }) {
    final results = <MultiTransferRoute>[];
    if (userPath.length < 4) return results;

    // Split path into thirds
    final splitPoints = [0.33, 0.66];
    final firstThird = (userPath.length * 0.33).floor();
    final secondThird = (userPath.length * 0.66).floor();

    final segment1 = userPath.sublist(0, firstThird + 1);
    final segment2 = userPath.sublist(firstThird, secondThird + 1);
    final segment3 = userPath.sublist(secondThird);

    if (segment1.length < 2 || segment2.length < 2 || segment3.length < 2) {
      return results;
    }

    // Find routes for each segment
    final matches1 = RouteMatcher.findMatchingRoutes(
      userPath: segment1,
      jeepneyRoutes: jeepneyRoutes,
      minMatchPercentage: 35.0,
      maxCount: 3,
    );

    final matches2 = RouteMatcher.findMatchingRoutes(
      userPath: segment2,
      jeepneyRoutes: jeepneyRoutes,
      minMatchPercentage: 35.0,
      maxCount: 3,
    );

    final matches3 = RouteMatcher.findMatchingRoutes(
      userPath: segment3,
      jeepneyRoutes: jeepneyRoutes,
      minMatchPercentage: 35.0,
      maxCount: 3,
    );

    // Combine matches
    for (final first in matches1) {
      for (final second in matches2) {
        for (final third in matches3) {
          // Skip duplicate routes in sequence
          if (first.route.id == second.route.id ||
              second.route.id == third.route.id)
            continue;

          final transfer1 = segment1.last;
          final transfer2 = segment2.last;

          final walk1 = _calculateWalkingDistanceToRoute(
            transfer1,
            second.route.path,
          );
          final walk2 = _calculateWalkingDistanceToRoute(
            transfer2,
            third.route.path,
          );

          if (walk1 <= maxWalkingDistance && walk2 <= maxWalkingDistance) {
            final multiRoute = _buildMultiTransferRoute(
              segments: [first.route, second.route, third.route],
              transferPoints: [transfer1, transfer2],
              walkingDistances: [walk1, walk2],
              startPoint: userPath.first,
              endPoint: userPath.last,
              landmarks: landmarks,
              matchPercentages: [
                first.matchPercentage,
                second.matchPercentage,
                third.matchPercentage,
              ],
            );
            if (multiRoute != null) {
              results.add(multiRoute);
            }
          }
        }
      }
    }

    return results;
  }

  /// Find all intersection points between routes
  static List<Map<String, dynamic>> _findRouteIntersections(
    List<JeepneyRoute> routes,
  ) {
    final intersections = <Map<String, dynamic>>[];

    for (int i = 0; i < routes.length; i++) {
      for (int j = i + 1; j < routes.length; j++) {
        final route1 = routes[i];
        final route2 = routes[j];

        if (route1.path.isEmpty || route2.path.isEmpty) continue;

        // Find closest points between the two routes
        final closestPoints = _findClosestPointsBetweenPaths(
          route1.path,
          route2.path,
        );

        if (closestPoints != null &&
            closestPoints['distance']! <= maxWalkingDistance) {
          intersections.add({
            'route1': route1,
            'route2': route2,
            'point': closestPoints['point1'],
            'point2': closestPoints['point2'],
            'distance': closestPoints['distance'],
          });
        }
      }
    }

    return intersections;
  }

  /// Find the closest points between two paths
  static Map<String, dynamic>? _findClosestPointsBetweenPaths(
    List<LatLng> path1,
    List<LatLng> path2,
  ) {
    double minDistance = double.infinity;
    LatLng? closestPoint1;
    LatLng? closestPoint2;

    // Sample paths for efficiency
    final sampled1 = _samplePath(path1, 30);
    final sampled2 = _samplePath(path2, 30);

    for (final p1 in sampled1) {
      for (final p2 in sampled2) {
        final dist = _haversineDistance(p1, p2) * 1000; // Convert to meters
        if (dist < minDistance) {
          minDistance = dist;
          closestPoint1 = p1;
          closestPoint2 = p2;
        }
      }
    }

    if (closestPoint1 == null) return null;

    return {
      'point1': closestPoint1,
      'point2': closestPoint2,
      'distance': minDistance,
    };
  }

  /// Check if a route covers a specific point
  static bool _routeCoversPoint(
    JeepneyRoute route,
    LatLng point,
    double bufferMeters,
  ) {
    for (final routePoint in route.path) {
      final dist = _haversineDistance(point, routePoint) * 1000;
      if (dist <= bufferMeters) {
        return true;
      }
    }
    return false;
  }

  /// Calculate walking distance from a point to nearest point on a route
  static double _calculateWalkingDistanceToRoute(
    LatLng point,
    List<LatLng> routePath,
  ) {
    double minDist = double.infinity;
    for (final routePoint in routePath) {
      final dist = _haversineDistance(point, routePoint) * 1000;
      if (dist < minDist) {
        minDist = dist;
      }
    }
    return minDist;
  }

  /// Build a MultiTransferRoute from segments
  static MultiTransferRoute? _buildMultiTransferRoute({
    required List<JeepneyRoute> segments,
    required List<LatLng> transferPoints,
    required List<double> walkingDistances,
    required LatLng startPoint,
    required LatLng endPoint,
    List<Map<String, dynamic>>? landmarks,
    List<double>? matchPercentages,
  }) {
    if (segments.isEmpty) return null;

    final routeSegments = <RouteSegment>[];
    final transfers = <TransferPoint>[];
    double totalFare = 0.0;
    double totalDistance = 0.0;
    double totalWalking = 0.0;

    // Build route segments
    for (int i = 0; i < segments.length; i++) {
      final route = segments[i];
      final segStart = i == 0 ? startPoint : transferPoints[i - 1];
      final segEnd = i == segments.length - 1 ? endPoint : transferPoints[i];

      // Estimate distance for this segment
      final segDistance = _haversineDistance(segStart, segEnd);

      // Calculate fare for this segment
      final segFare = _calculateFare(segDistance, route.baseFare);

      routeSegments.add(
        RouteSegment(
          route: route,
          startPoint: segStart,
          endPoint: segEnd,
          distanceKm: segDistance,
          fare: segFare,
          matchPercentage:
              matchPercentages != null && i < matchPercentages.length
              ? matchPercentages[i]
              : 70.0,
        ),
      );

      totalFare += segFare;
      totalDistance += segDistance;
    }

    // Build transfer points
    for (int i = 0; i < transferPoints.length; i++) {
      final tpLocation = transferPoints[i];
      final walkDist = walkingDistances[i];
      totalWalking += walkDist;

      // Find nearest landmark
      String? landmarkName;
      int? landmarkId;
      if (landmarks != null) {
        final nearestLandmark = _findNearestLandmark(tpLocation, landmarks);
        if (nearestLandmark != null) {
          landmarkName = nearestLandmark['name'] as String?;
          landmarkId = nearestLandmark['id'] as int?;
        }
      }

      transfers.add(
        TransferPoint(
          location: tpLocation,
          landmarkName: landmarkName ?? 'Transfer Point ${i + 1}',
          landmarkId: landmarkId,
          walkingDistanceMeters: walkDist,
          fromRoute: segments[i],
          toRoute: segments[i + 1],
        ),
      );
    }

    // Calculate score (lower is better)
    // Factors: transfers (penalty), total fare, walking distance, average match %
    final avgMatch = matchPercentages != null && matchPercentages.isNotEmpty
        ? matchPercentages.reduce((a, b) => a + b) / matchPercentages.length
        : 70.0;

    final score =
        (segments.length - 1) * 50.0 + // Transfer penalty
        totalFare * 2.0 + // Fare weight
        totalWalking / 10.0 + // Walking weight
        (100 - avgMatch); // Match bonus (lower difference = better)

    return MultiTransferRoute(
      segments: routeSegments,
      transferPoints: transfers,
      totalFare: totalFare,
      totalDistanceKm: totalDistance,
      totalWalkingDistanceMeters: totalWalking,
      transferCount: segments.length - 1,
      score: score,
    );
  }

  /// Find nearest landmark to a point
  static Map<String, dynamic>? _findNearestLandmark(
    LatLng point,
    List<Map<String, dynamic>> landmarks,
  ) {
    double minDist = double.infinity;
    Map<String, dynamic>? nearest;

    for (final landmark in landmarks) {
      final lat = landmark['latitude'] as double?;
      final lng = landmark['longitude'] as double?;
      if (lat == null || lng == null) continue;

      final dist = _haversineDistance(point, LatLng(lat, lng)) * 1000;
      if (dist < minDist && dist < 200) {
        // Within 200m
        minDist = dist;
        nearest = landmark;
      }
    }

    return nearest;
  }

  /// Calculate fare based on distance
  static double _calculateFare(double distanceKm, double baseFare) {
    const double baseDistance = 4.0; // First 4km
    const double additionalRatePerKm = 1.80;

    if (distanceKm <= baseDistance) {
      return baseFare;
    }

    final additionalKm = distanceKm - baseDistance;
    return baseFare + (additionalKm * additionalRatePerKm);
  }

  /// Sample a path to reduce points
  static List<LatLng> _samplePath(List<LatLng> path, int maxPoints) {
    if (path.length <= maxPoints) return path;

    final step = path.length / maxPoints;
    final sampled = <LatLng>[];

    for (int i = 0; i < maxPoints; i++) {
      final index = (i * step).floor();
      if (index < path.length) {
        sampled.add(path[index]);
      }
    }

    if (sampled.last != path.last) {
      sampled.add(path.last);
    }

    return sampled;
  }

  /// Haversine distance in km
  static double _haversineDistance(LatLng p1, LatLng p2) {
    final lat1 = p1.latitude * pi / 180;
    final lat2 = p2.latitude * pi / 180;
    final dLat = (p2.latitude - p1.latitude) * pi / 180;
    final dLng = (p2.longitude - p1.longitude) * pi / 180;

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return _earthRadiusKm * c;
  }
}
