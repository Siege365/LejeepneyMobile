import 'dart:math';
import 'package:latlong2/latlong.dart';

/// Shared geographic utility functions for transit routing
class GeoUtils {
  static const double earthRadiusKm = 6371.0;

  /// Calculate distance between two points using Haversine formula (returns km)
  static double haversineDistance(LatLng point1, LatLng point2) {
    final lat1 = point1.latitude * pi / 180;
    final lat2 = point2.latitude * pi / 180;
    final dLat = (point2.latitude - point1.latitude) * pi / 180;
    final dLng = (point2.longitude - point1.longitude) * pi / 180;

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadiusKm * c;
  }

  /// Calculate distance in meters
  static double distanceMeters(LatLng point1, LatLng point2) {
    return haversineDistance(point1, point2) * 1000;
  }

  /// Find minimum distance from a point to a polyline path (in meters)
  static double minDistanceToPath(LatLng point, List<LatLng> path) {
    if (path.isEmpty) return double.infinity;
    if (path.length == 1) return distanceMeters(point, path.first);

    double minDistance = double.infinity;

    for (int i = 0; i < path.length - 1; i++) {
      final distance = distanceToSegment(point, path[i], path[i + 1]);
      if (distance < minDistance) {
        minDistance = distance;
      }
    }

    return minDistance;
  }

  /// Calculate distance from a point to a line segment (in meters)
  static double distanceToSegment(
    LatLng point,
    LatLng segStart,
    LatLng segEnd,
  ) {
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
      return distanceMeters(point, segStart);
    }

    double t = (apx * abx + apy * aby) / ab2;
    t = t.clamp(0.0, 1.0);

    final closestLng = ax + t * abx;
    final closestLat = ay + t * aby;
    final closestPoint = LatLng(closestLat, closestLng);

    return distanceMeters(point, closestPoint);
  }

  /// Find the closest point on a path to a given point
  static LatLng findClosestPointOnPath(LatLng point, List<LatLng> path) {
    if (path.isEmpty) return point;
    if (path.length == 1) return path.first;

    double minDistance = double.infinity;
    LatLng closestPoint = path.first;

    for (int i = 0; i < path.length - 1; i++) {
      final projected = projectPointToSegment(point, path[i], path[i + 1]);
      final distance = distanceMeters(point, projected);
      if (distance < minDistance) {
        minDistance = distance;
        closestPoint = projected;
      }
    }

    return closestPoint;
  }

  /// Project a point onto a line segment
  static LatLng projectPointToSegment(
    LatLng point,
    LatLng segStart,
    LatLng segEnd,
  ) {
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

    if (ab2 == 0) return segStart;

    double t = (apx * abx + apy * aby) / ab2;
    t = t.clamp(0.0, 1.0);

    return LatLng(ay + t * aby, ax + t * abx);
  }

  /// Calculate total length of a path in km
  static double pathLength(List<LatLng> path) {
    if (path.length < 2) return 0.0;

    double length = 0.0;
    for (int i = 0; i < path.length - 1; i++) {
      length += haversineDistance(path[i], path[i + 1]);
    }
    return length;
  }

  /// Sample a path to reduce computation
  static List<LatLng> samplePath(List<LatLng> path, {int maxPoints = 50}) {
    if (path.length <= maxPoints) return List.from(path);

    final step = path.length / maxPoints;
    final sampled = <LatLng>[];

    for (int i = 0; i < maxPoints; i++) {
      final index = (i * step).floor();
      if (index < path.length) {
        sampled.add(path[index]);
      }
    }

    if (sampled.isNotEmpty && sampled.last != path.last) {
      sampled.add(path.last);
    }

    return sampled;
  }

  /// Get bounding box of a path
  static Map<String, double> getBoundingBox(List<LatLng> path) {
    if (path.isEmpty) {
      return {'minLat': 0, 'maxLat': 0, 'minLng': 0, 'maxLng': 0};
    }

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

  /// Check if two bounding boxes overlap with buffer
  static bool boundingBoxesOverlap(
    List<LatLng> path1,
    List<LatLng> path2,
    double bufferMeters,
  ) {
    final box1 = getBoundingBox(path1);
    final box2 = getBoundingBox(path2);
    final bufferDeg = bufferMeters / 111000.0;

    return !(box1['maxLat']! + bufferDeg < box2['minLat']! ||
        box1['minLat']! - bufferDeg > box2['maxLat']! ||
        box1['maxLng']! + bufferDeg < box2['minLng']! ||
        box1['minLng']! - bufferDeg > box2['maxLng']!);
  }

  /// Find the index of the point in path closest to the given point
  static int findClosestPointIndex(LatLng point, List<LatLng> path) {
    if (path.isEmpty) return -1;

    int closestIndex = 0;
    double minDistance = double.infinity;

    for (int i = 0; i < path.length; i++) {
      final distance = distanceMeters(point, path[i]);
      if (distance < minDistance) {
        minDistance = distance;
        closestIndex = i;
      }
    }

    return closestIndex;
  }

  /// Check if traveling from fromIndex to toIndex follows the forward
  /// direction of the route path. Returns true when toIndex >= fromIndex.
  static bool isForwardTravel(int fromIndex, int toIndex) {
    return toIndex >= fromIndex;
  }

  /// Get the bearing (travel direction in degrees) of a route at a given path
  /// index. Uses the segment starting at [index] (or ending at [index] if it
  /// is the last point).
  static double getBearingAtIndex(List<LatLng> path, int index) {
    if (path.length < 2) return 0.0;
    if (index >= path.length - 1) {
      // Last point – use the bearing of the final segment
      return calculateBearing(path[path.length - 2], path[path.length - 1]);
    }
    return calculateBearing(path[index], path[index + 1]);
  }

  /// Extract a sub-path between two points **only in forward direction**.
  /// Returns an empty list when the start comes after the end on the path
  /// (i.e. would require traveling backwards).
  static List<LatLng> extractSubPath(
    List<LatLng> fullPath,
    LatLng start,
    LatLng end,
  ) {
    if (fullPath.isEmpty) return [];

    final startIndex = findClosestPointIndex(start, fullPath);
    final endIndex = findClosestPointIndex(end, fullPath);

    if (startIndex == -1 || endIndex == -1) return [];

    // Only allow forward travel along the route
    if (startIndex > endIndex) {
      return []; // Reverse direction – not a valid sub-path
    }

    return fullPath.sublist(startIndex, endIndex + 1);
  }

  /// Calculate bearing from one point to another (in degrees)
  static double calculateBearing(LatLng from, LatLng to) {
    final lat1 = from.latitude * pi / 180;
    final lat2 = to.latitude * pi / 180;
    final dLng = (to.longitude - from.longitude) * pi / 180;

    final y = sin(dLng) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng);

    return (atan2(y, x) * 180 / pi + 360) % 360;
  }

  /// Estimate walking time in minutes
  static double estimateWalkingTime(
    double distanceKm, {
    double speedKmh = 4.0,
  }) {
    return (distanceKm / speedKmh) * 60;
  }

  /// Estimate jeepney travel time in minutes
  static double estimateJeepneyTime(
    double distanceKm, {
    double speedKmh = 15.0,
  }) {
    return (distanceKm / speedKmh) * 60;
  }
}
