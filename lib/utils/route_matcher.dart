import 'dart:math';
import 'package:latlong2/latlong.dart';
import '../models/jeepney_route.dart';

/// Result of matching a user's route against a jeepney route
class RouteMatchResult {
  final JeepneyRoute route;
  final double matchPercentage; // 0-100
  final double coveragePercentage; // How much of user's route is covered
  final double overlapDistanceKm; // Approximate overlap distance

  RouteMatchResult({
    required this.route,
    required this.matchPercentage,
    required this.coveragePercentage,
    required this.overlapDistanceKm,
  });

  @override
  String toString() =>
      'RouteMatchResult(${route.name}: ${matchPercentage.toStringAsFixed(1)}% match)';
}

/// Utility class for matching user's calculated route path against admin-created jeepney routes
class RouteMatcher {
  // Earth radius in km for distance calculations
  static const double _earthRadiusKm = 6371.0;

  // Buffer distance in meters - points within this distance are considered "on the route"
  static const double _bufferDistanceMeters = 100.0;

  // Minimum match percentage to be considered a valid match
  static const double minimumMatchThreshold = 50.0;

  // Maximum results to return
  static const int maxResults = 5;

  /// Find jeepney routes that match the user's calculated path
  /// Returns top matching routes sorted by match percentage (descending)
  static List<RouteMatchResult> findMatchingRoutes({
    required List<LatLng> userPath,
    required List<JeepneyRoute> jeepneyRoutes,
    double bufferMeters = _bufferDistanceMeters,
    double minMatchPercentage = minimumMatchThreshold,
    int maxCount = maxResults,
  }) {
    if (userPath.isEmpty) {
      return [];
    }

    final results = <RouteMatchResult>[];

    for (final jeepneyRoute in jeepneyRoutes) {
      // Skip routes with no path data
      if (jeepneyRoute.path.isEmpty) continue;

      // Quick bounding box check to skip routes that are clearly too far
      if (!_boundingBoxesOverlap(
        userPath,
        jeepneyRoute.path,
        bufferMeters * 3,
      )) {
        continue;
      }

      // Calculate detailed match score
      final matchResult = _calculatePathMatch(
        userPath: userPath,
        jeepneyPath: jeepneyRoute.path,
        bufferMeters: bufferMeters,
        jeepneyRoute: jeepneyRoute,
      );

      if (matchResult != null &&
          matchResult.matchPercentage >= minMatchPercentage) {
        results.add(matchResult);
      }
    }

    // Sort by match percentage (highest first)
    results.sort((a, b) => b.matchPercentage.compareTo(a.matchPercentage));

    // Return top N results
    return results.take(maxCount).toList();
  }

  /// Check if two paths' bounding boxes overlap (quick rejection test)
  static bool _boundingBoxesOverlap(
    List<LatLng> path1,
    List<LatLng> path2,
    double bufferMeters,
  ) {
    // Get bounding boxes
    final box1 = _getBoundingBox(path1);
    final box2 = _getBoundingBox(path2);

    // Convert buffer to approximate degrees (rough approximation)
    final bufferDeg = bufferMeters / 111000.0; // ~111km per degree

    // Check overlap with buffer
    return !(box1['maxLat']! + bufferDeg < box2['minLat']! ||
        box1['minLat']! - bufferDeg > box2['maxLat']! ||
        box1['maxLng']! + bufferDeg < box2['minLng']! ||
        box1['minLng']! - bufferDeg > box2['maxLng']!);
  }

  /// Get bounding box of a path
  static Map<String, double> _getBoundingBox(List<LatLng> path) {
    double minLat = double.infinity;
    double maxLat = double.negativeInfinity;
    double minLng = double.infinity;
    double maxLng = double.negativeInfinity;

    for (final point in path) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    return {
      'minLat': minLat,
      'maxLat': maxLat,
      'minLng': minLng,
      'maxLng': maxLng,
    };
  }

  /// Calculate how well the user's path matches a jeepney route
  /// Uses a buffer-based approach: count how many user path points fall within buffer of jeepney route
  static RouteMatchResult? _calculatePathMatch({
    required List<LatLng> userPath,
    required List<LatLng> jeepneyPath,
    required double bufferMeters,
    required JeepneyRoute jeepneyRoute,
  }) {
    if (userPath.isEmpty || jeepneyPath.isEmpty) return null;

    // Sample user path to reduce computation (take every Nth point)
    final sampledUserPath = _samplePath(userPath, maxPoints: 50);

    int matchingPoints = 0;
    double totalOverlapDistance = 0.0;

    for (int i = 0; i < sampledUserPath.length; i++) {
      final userPoint = sampledUserPath[i];

      // Find minimum distance from this point to any segment of the jeepney route
      final minDistance = _minDistanceToPath(userPoint, jeepneyPath);

      if (minDistance <= bufferMeters) {
        matchingPoints++;

        // Estimate overlap distance (distance to next point if both match)
        if (i < sampledUserPath.length - 1) {
          final nextUserPoint = sampledUserPath[i + 1];
          final nextMinDistance = _minDistanceToPath(
            nextUserPoint,
            jeepneyPath,
          );
          if (nextMinDistance <= bufferMeters) {
            totalOverlapDistance += _haversineDistance(
              userPoint,
              nextUserPoint,
            );
          }
        }
      }
    }

    if (matchingPoints == 0) return null;

    // Calculate match percentage
    final matchPercentage = (matchingPoints / sampledUserPath.length) * 100;

    // Calculate coverage - how much of user's total path is covered
    final userPathLength = _calculatePathLength(userPath);
    final coveragePercentage = userPathLength > 0
        ? min(100.0, (totalOverlapDistance / userPathLength) * 100)
        : 0.0;

    return RouteMatchResult(
      route: jeepneyRoute,
      matchPercentage: matchPercentage,
      coveragePercentage: coveragePercentage,
      overlapDistanceKm: totalOverlapDistance,
    );
  }

  /// Sample a path to reduce computation - take evenly spaced points
  static List<LatLng> _samplePath(List<LatLng> path, {int maxPoints = 50}) {
    if (path.length <= maxPoints) return path;

    final step = path.length / maxPoints;
    final sampled = <LatLng>[];

    for (int i = 0; i < maxPoints; i++) {
      final index = (i * step).floor();
      if (index < path.length) {
        sampled.add(path[index]);
      }
    }

    // Always include the last point
    if (sampled.last != path.last) {
      sampled.add(path.last);
    }

    return sampled;
  }

  /// Find minimum distance from a point to a polyline path (in meters)
  static double _minDistanceToPath(LatLng point, List<LatLng> path) {
    double minDistance = double.infinity;

    for (int i = 0; i < path.length - 1; i++) {
      final segmentStart = path[i];
      final segmentEnd = path[i + 1];

      // Distance from point to line segment
      final distance = _distanceToSegment(point, segmentStart, segmentEnd);
      if (distance < minDistance) {
        minDistance = distance;
      }
    }

    // Also check distance to first and last points
    final distToFirst = _haversineDistance(point, path.first) * 1000;
    final distToLast = _haversineDistance(point, path.last) * 1000;
    minDistance = min(minDistance, min(distToFirst, distToLast));

    return minDistance;
  }

  /// Calculate distance from a point to a line segment (in meters)
  static double _distanceToSegment(
    LatLng point,
    LatLng segStart,
    LatLng segEnd,
  ) {
    // Convert to cartesian for projection calculation
    final px = point.longitude;
    final py = point.latitude;
    final ax = segStart.longitude;
    final ay = segStart.latitude;
    final bx = segEnd.longitude;
    final by = segEnd.latitude;

    final abx = bx - ax;
    final aby = by - ay;
    final apx = px - ax;
    final apy = py - ay;

    final ab2 = abx * abx + aby * aby;

    if (ab2 == 0) {
      // Segment is a point
      return _haversineDistance(point, segStart) * 1000;
    }

    // Project point onto segment line, clamped to [0,1]
    double t = (apx * abx + apy * aby) / ab2;
    t = t.clamp(0.0, 1.0);

    // Closest point on segment
    final closestLng = ax + t * abx;
    final closestLat = ay + t * aby;
    final closestPoint = LatLng(closestLat, closestLng);

    return _haversineDistance(point, closestPoint) *
        1000; // Convert km to meters
  }

  /// Calculate distance between two points using Haversine formula (returns km)
  static double _haversineDistance(LatLng point1, LatLng point2) {
    final lat1 = point1.latitude * pi / 180;
    final lat2 = point2.latitude * pi / 180;
    final dLat = (point2.latitude - point1.latitude) * pi / 180;
    final dLng = (point2.longitude - point1.longitude) * pi / 180;

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return _earthRadiusKm * c;
  }

  /// Calculate total length of a path in km
  static double _calculatePathLength(List<LatLng> path) {
    double length = 0.0;
    for (int i = 0; i < path.length - 1; i++) {
      length += _haversineDistance(path[i], path[i + 1]);
    }
    return length;
  }

  /// Calculate Hausdorff distance between two paths (alternative matching algorithm)
  /// This is more accurate but slower - use for verification if needed
  static double calculateHausdorffDistance(
    List<LatLng> path1,
    List<LatLng> path2,
  ) {
    final d1 = _directedHausdorff(path1, path2);
    final d2 = _directedHausdorff(path2, path1);
    return max(d1, d2);
  }

  /// One-directional Hausdorff distance
  static double _directedHausdorff(List<LatLng> from, List<LatLng> to) {
    double maxMin = 0.0;
    for (final p in from) {
      final minDist = _minDistanceToPath(p, to);
      if (minDist > maxMin) {
        maxMin = minDist;
      }
    }
    return maxMin;
  }
}
