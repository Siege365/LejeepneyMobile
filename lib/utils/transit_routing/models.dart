import 'package:latlong2/latlong.dart';
import '../../models/jeepney_route.dart';

/// Represents a node in the jeepney transit graph
/// Can be a route endpoint, intersection point, or user location
class TransitNode {
  final String id;
  final LatLng location;
  final TransitNodeType type;
  final String? name;
  final int? landmarkId;
  final List<String> connectedRouteIds;

  TransitNode({
    required this.id,
    required this.location,
    required this.type,
    this.name,
    this.landmarkId,
    this.connectedRouteIds = const [],
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransitNode &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'TransitNode($id, ${type.name}, $name)';
}

enum TransitNodeType {
  routeEndpoint, // Start or end of a jeepney route
  intersection, // Where two routes meet/cross
  userOrigin, // User's starting point
  userDestination, // User's destination
  accessPoint, // Point where user can board/alight
}

/// Represents an edge in the jeepney transit graph
class TransitEdge {
  final String id;
  final TransitNode from;
  final TransitNode to;
  final TransitEdgeType type;
  final JeepneyRoute? route; // null for walking edges
  final double distanceKm;
  final double estimatedTimeMinutes;
  final double fare; // 0 for walking

  TransitEdge({
    required this.id,
    required this.from,
    required this.to,
    required this.type,
    this.route,
    required this.distanceKm,
    required this.estimatedTimeMinutes,
    required this.fare,
  });

  @override
  String toString() =>
      'TransitEdge(${from.id} -> ${to.id}, ${type.name}, ${distanceKm.toStringAsFixed(2)}km)';
}

enum TransitEdgeType {
  jeepneyRide, // Travel on a jeepney route
  walking, // Walking between points
  transfer, // Walking transfer between routes
}

/// A segment of a transit journey
class JourneySegment {
  final JeepneyRoute? route; // null for walking segments
  final LatLng startPoint;
  final LatLng endPoint;
  final String? startName;
  final String? endName;
  final JourneySegmentType type;
  final double distanceKm;
  final double fare;
  final double estimatedTimeMinutes;
  final double matchPercentage; // For jeepney segments

  JourneySegment({
    this.route,
    required this.startPoint,
    required this.endPoint,
    this.startName,
    this.endName,
    required this.type,
    required this.distanceKm,
    required this.fare,
    required this.estimatedTimeMinutes,
    this.matchPercentage = 100.0,
  });

  bool get isWalking => type == JourneySegmentType.walking;
  bool get isTransfer => type == JourneySegmentType.transfer;
  bool get isJeepneyRide => type == JourneySegmentType.jeepneyRide;

  @override
  String toString() {
    if (isWalking || isTransfer) {
      return 'Walk ${distanceKm.toStringAsFixed(2)}km to ${endName ?? 'destination'}';
    }
    return 'Take ${route?.routeNumber ?? 'Unknown'} (${distanceKm.toStringAsFixed(2)}km, ₱${fare.toStringAsFixed(2)})';
  }
}

enum JourneySegmentType {
  walking, // Walk to first stop or from last stop
  transfer, // Walk between routes (transfer)
  jeepneyRide, // Ride a jeepney
}

/// Complete suggested route from origin to destination
class SuggestedRoute {
  final String id;
  final List<JourneySegment> segments;
  final double totalFare;
  final double totalDistanceKm;
  final double totalWalkingDistanceKm;
  final double estimatedTimeMinutes;
  final int transferCount;
  final double score; // Lower is better
  final RouteSourceType sourceType;
  final double? osrmMatchPercentage; // If validated against OSRM

  SuggestedRoute({
    required this.id,
    required this.segments,
    required this.totalFare,
    required this.totalDistanceKm,
    required this.totalWalkingDistanceKm,
    required this.estimatedTimeMinutes,
    required this.transferCount,
    required this.score,
    required this.sourceType,
    this.osrmMatchPercentage,
  });

  /// Get list of jeepney routes used
  List<JeepneyRoute> get routes =>
      segments.where((s) => s.route != null).map((s) => s.route!).toList();

  /// Get route names as display string
  String get routeNames => routes.map((r) => r.routeNumber).join(' → ');

  /// Get transfer point names
  String get transferSummary {
    final transfers = <String>[];
    for (int i = 0; i < segments.length; i++) {
      if (segments[i].isTransfer) {
        transfers.add(segments[i].endName ?? 'Transfer Point');
      }
    }
    return transfers.join(', ');
  }

  @override
  String toString() =>
      'SuggestedRoute($routeNames, $transferCount transfers, ₱${totalFare.toStringAsFixed(2)}, ${totalDistanceKm.toStringAsFixed(2)}km)';
}

/// Source of the route suggestion
enum RouteSourceType {
  osrmValidated, // OSRM path validated against jeepney routes
  jeepneyBased, // Generated from jeepney route data only
  hybrid, // Combination of both approaches
}

/// Result of route accuracy validation
class RouteValidationResult {
  final bool isAccurate;
  final double coveragePercentage;
  final double maxGapMeters;
  final List<LatLng> uncoveredSegments;
  final String reason;

  RouteValidationResult({
    required this.isAccurate,
    required this.coveragePercentage,
    required this.maxGapMeters,
    required this.uncoveredSegments,
    required this.reason,
  });

  @override
  String toString() =>
      'RouteValidationResult(accurate: $isAccurate, coverage: ${coveragePercentage.toStringAsFixed(1)}%, maxGap: ${maxGapMeters.toStringAsFixed(0)}m)';
}

/// Configuration for the hybrid routing system
class HybridRoutingConfig {
  /// Minimum OSRM path coverage to be considered accurate
  final double minCoveragePercentage;

  /// Maximum gap in coverage before flagging as inaccurate (meters)
  final double maxCoverageGapMeters;

  /// Maximum walking distance to access a route (meters)
  final double maxAccessWalkingMeters;

  /// Maximum walking distance between transfers (meters)
  final double maxTransferWalkingMeters;

  /// Maximum number of transfers allowed
  final int maxTransfers;

  /// Maximum results to return
  final int maxResults;

  /// Walking speed for time estimation (km/h)
  final double walkingSpeedKmh;

  /// Average jeepney speed (km/h)
  final double jeepneySpeedKmh;

  const HybridRoutingConfig({
    this.minCoveragePercentage = 40.0,
    this.maxCoverageGapMeters = 500.0,
    this.maxAccessWalkingMeters = 500.0,
    this.maxTransferWalkingMeters = 300.0,
    this.maxTransfers = 2,
    this.maxResults = 5,
    this.walkingSpeedKmh = 4.0,
    this.jeepneySpeedKmh = 15.0,
  });

  /// Default configuration
  static const HybridRoutingConfig defaultConfig = HybridRoutingConfig();
}
