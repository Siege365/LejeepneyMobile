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
  final List<LatLng>?
  walkingPath; // Road-snapped path for walking/transfer segments

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
    this.walkingPath,
  });

  bool get isWalking => type == JourneySegmentType.walking;
  bool get isTransfer => type == JourneySegmentType.transfer;
  bool get isJeepneyRide => type == JourneySegmentType.jeepneyRide;

  /// Parse a journey segment from the Laravel server JSON response.
  ///
  /// Expected format (Laravel `POST /api/v1/routes/find`):
  /// ```json
  /// {
  ///   "type": "walking" | "jeepney_ride",
  ///   "route_id": 12,                    // only for jeepney_ride
  ///   "route_number": "01A",             // only for jeepney_ride
  ///   "route_name": "Maa - Agdao",       // only for jeepney_ride
  ///   "route_color": "#d6ce1f",          // only for jeepney_ride
  ///   "from": { "lat": 7.07, "lng": 125.61 },
  ///   "to": { "lat": 7.071, "lng": 125.611 },
  ///   "from_name": "Your Location",
  ///   "to_name": "Boarding Point",
  ///   "distance_km": 0.045,
  ///   "fare": 13.00,
  ///   "estimated_time_minutes": 1,
  ///   "path": [ {"lat": ..., "lng": ...}, ... ]  // when include_walking_paths=true
  /// }
  /// ```
  ///
  /// Note: Laravel only returns "walking" and "jeepney_ride" types.
  /// Transfer inference (walking between two rides) is done in
  /// [SuggestedRoute.fromServerJson].
  factory JourneySegment.fromServerJson(
    Map<String, dynamic> json, {
    JourneySegmentType? typeOverride,
  }) {
    // Parse segment type (server only sends "walking" and "jeepney_ride")
    final typeStr = (json['type'] as String?)?.toLowerCase() ?? 'walking';
    final JourneySegmentType segType;
    if (typeOverride != null) {
      segType = typeOverride;
    } else {
      switch (typeStr) {
        case 'jeepney_ride':
          segType = JourneySegmentType.jeepneyRide;
          break;
        default:
          segType = JourneySegmentType.walking;
      }
    }

    // Build JeepneyRoute from flat fields (only for jeepney_ride segments)
    JeepneyRoute? route;
    if (typeStr == 'jeepney_ride' && json['route_id'] != null) {
      route = JeepneyRoute(
        id: (json['route_id'] as num?)?.toInt() ?? 0,
        name: (json['route_name'] as String?) ?? '',
        routeNumber: (json['route_number'] as String?) ?? '',
        baseFare: (json['fare'] as num?)?.toDouble() ?? 13.0,
        color: json['route_color'] as String?,
        status: 'available',
      );
    }

    // Parse from/to points
    final fromPt = json['from'] as Map<String, dynamic>? ?? {};
    final toPt = json['to'] as Map<String, dynamic>? ?? {};

    // Parse path (walking path when include_walking_paths=true, or ride path)
    List<LatLng>? walkingPath;
    if (json['path'] != null && json['path'] is List) {
      walkingPath = (json['path'] as List).map<LatLng>((c) {
        if (c is Map) {
          return LatLng(
            (c['lat'] as num?)?.toDouble() ?? 0.0,
            (c['lng'] as num?)?.toDouble() ?? 0.0,
          );
        }
        return LatLng(0, 0);
      }).toList();
    }

    return JourneySegment(
      route: route,
      startPoint: LatLng(
        (fromPt['lat'] as num?)?.toDouble() ?? 0.0,
        (fromPt['lng'] as num?)?.toDouble() ?? 0.0,
      ),
      endPoint: LatLng(
        (toPt['lat'] as num?)?.toDouble() ?? 0.0,
        (toPt['lng'] as num?)?.toDouble() ?? 0.0,
      ),
      startName: json['from_name'] as String?,
      endName: json['to_name'] as String?,
      type: segType,
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0.0,
      fare: (json['fare'] as num?)?.toDouble() ?? 0.0,
      estimatedTimeMinutes:
          (json['estimated_time_minutes'] as num?)?.toDouble() ?? 0.0,
      walkingPath: walkingPath,
    );
  }

  @override
  String toString() {
    if (isWalking || isTransfer) {
      return 'Walk ${distanceKm.toStringAsFixed(2)}km to ${endName ?? 'destination'}';
    }
    final routeLabel = route != null
        ? (route!.routeNumber.isNotEmpty ? route!.routeNumber : route!.name)
        : 'Unknown';
    return 'Take $routeLabel (${distanceKm.toStringAsFixed(2)}km, ₱${fare.toStringAsFixed(2)})';
  }
}

enum JourneySegmentType {
  walking, // Walk to first stop or from last stop
  transfer, // Walk between routes (transfer)
  jeepneyRide, // Ride a jeepney
}

/// Fare breakdown from the server, with regular and discounted prices
class FareBreakdown {
  final double regular;
  final double student;
  final double senior;
  final List<double> perSegment;

  FareBreakdown({
    required this.regular,
    required this.student,
    required this.senior,
    this.perSegment = const [],
  });

  factory FareBreakdown.fromJson(Map<String, dynamic> json) {
    final perSegmentList = <double>[];
    if (json['per_segment'] != null && json['per_segment'] is List) {
      for (final item in json['per_segment'] as List) {
        perSegmentList.add((item as num?)?.toDouble() ?? 0.0);
      }
    }
    return FareBreakdown(
      regular: (json['regular'] as num?)?.toDouble() ?? 0.0,
      student: (json['student'] as num?)?.toDouble() ?? 0.0,
      senior: (json['senior'] as num?)?.toDouble() ?? 0.0,
      perSegment: perSegmentList,
    );
  }

  @override
  String toString() =>
      'FareBreakdown(regular: ₱${regular.toStringAsFixed(2)}, student: ₱${student.toStringAsFixed(2)}, senior: ₱${senior.toStringAsFixed(2)})';
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
  final FareBreakdown? fareBreakdown; // Server-provided fare breakdown

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
    this.fareBreakdown,
  });

  /// Parse a suggested route from the Laravel server JSON response.
  ///
  /// Expected format (`POST /api/v1/routes/find`):
  /// ```json
  /// {
  ///   "id": "uuid",
  ///   "transfer_count": 0,
  ///   "total_fare": 13.00,
  ///   "total_distance_km": 5.42,
  ///   "total_walking_km": 0.312,
  ///   "estimated_time_minutes": 18,
  ///   "score": 42.50,
  ///   "segments": [ ... ],
  ///   "fare_breakdown": { "regular": 13.00, "student": 10.40, "senior": 10.40, "per_segment": [13.00] }
  /// }
  /// ```
  ///
  /// Transfer inference: Laravel only sends "walking" and "jeepney_ride".
  /// A walking segment between two jeepney_ride segments is re-typed as
  /// [JourneySegmentType.transfer].
  factory SuggestedRoute.fromServerJson(Map<String, dynamic> json) {
    // Parse segments with raw types first
    final segmentsJson = json['segments'] as List? ?? [];
    final rawSegments = segmentsJson
        .map<JourneySegment>(
          (s) => JourneySegment.fromServerJson(s as Map<String, dynamic>),
        )
        .toList();

    // Infer transfer type: a walking segment between two ride segments
    final segments = <JourneySegment>[];
    for (int i = 0; i < rawSegments.length; i++) {
      final seg = rawSegments[i];
      if (seg.isWalking && i > 0 && i < rawSegments.length - 1) {
        // Check if previous and next are rides
        final prevIsRide = rawSegments[i - 1].isJeepneyRide;
        final nextIsRide = rawSegments[i + 1].isJeepneyRide;
        if (prevIsRide && nextIsRide) {
          // Re-create as transfer type
          segments.add(
            JourneySegment(
              route: seg.route,
              startPoint: seg.startPoint,
              endPoint: seg.endPoint,
              startName: seg.startName,
              endName: seg.endName,
              type: JourneySegmentType.transfer,
              distanceKm: seg.distanceKm,
              fare: seg.fare,
              estimatedTimeMinutes: seg.estimatedTimeMinutes,
              walkingPath: seg.walkingPath,
            ),
          );
          continue;
        }
      }
      segments.add(seg);
    }

    // Parse fare breakdown
    FareBreakdown? fareBreakdown;
    if (json['fare_breakdown'] != null &&
        json['fare_breakdown'] is Map<String, dynamic>) {
      fareBreakdown = FareBreakdown.fromJson(
        json['fare_breakdown'] as Map<String, dynamic>,
      );
    }

    return SuggestedRoute(
      id: (json['id'] ?? 'server-${DateTime.now().millisecondsSinceEpoch}')
          .toString(),
      segments: segments,
      totalFare: (json['total_fare'] as num?)?.toDouble() ?? 0.0,
      totalDistanceKm: (json['total_distance_km'] as num?)?.toDouble() ?? 0.0,
      totalWalkingDistanceKm:
          (json['total_walking_km'] as num?)?.toDouble() ?? 0.0,
      estimatedTimeMinutes:
          (json['estimated_time_minutes'] as num?)?.toDouble() ?? 0.0,
      transferCount: (json['transfer_count'] as num?)?.toInt() ?? 0,
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      sourceType: RouteSourceType.hybrid,
      fareBreakdown: fareBreakdown,
    );
  }

  /// Get list of jeepney routes used
  List<JeepneyRoute> get routes =>
      segments.where((s) => s.route != null).map((s) => s.route!).toList();

  /// Get route names as display string (falls back to name if routeNumber empty)
  String get routeNames => routes
      .map((r) => r.routeNumber.isNotEmpty ? r.routeNumber : r.name)
      .join(' → ');

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

  /// Calculate discounted fare (uses server breakdown if available, else 20%)
  double get discountedFare => fareBreakdown?.student ?? (totalFare * 0.80);

  /// Get senior/PWD fare (uses server breakdown if available, else 20%)
  double get seniorFare => fareBreakdown?.senior ?? (totalFare * 0.80);

  /// Get discount amount
  double get discountAmount => totalFare - discountedFare;

  /// Whether this is a direct route with no transfers
  bool get isDirectRoute => transferCount == 0;

  /// Get all transfer locations (alight points from each transfer segment)
  List<LatLng> get transferLocations {
    final locations = <LatLng>[];
    for (final segment in segments) {
      if (segment.isTransfer) {
        locations.add(segment.startPoint); // Alight point (on prev route)
      }
    }
    return locations;
  }

  /// Get the boarding point where user first gets on a jeepney
  LatLng? get originBoardingPoint {
    for (final segment in segments) {
      if (segment.isJeepneyRide) return segment.startPoint;
    }
    return null;
  }

  /// Get the final drop-off point where user alights the last jeepney
  LatLng? get destinationDropOff {
    for (int i = segments.length - 1; i >= 0; i--) {
      if (segments[i].isJeepneyRide) return segments[i].endPoint;
    }
    return null;
  }

  /// Get transfer alight-board pairs: [(alight point, board point)]
  List<(LatLng alight, LatLng board)> get transferPointPairs {
    final pairs = <(LatLng, LatLng)>[];
    for (final segment in segments) {
      if (segment.isTransfer) {
        pairs.add((segment.startPoint, segment.endPoint));
      }
    }
    return pairs;
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
    this.maxAccessWalkingMeters = 1000.0,
    this.maxTransferWalkingMeters = 300.0,
    this.maxTransfers = 2,
    this.maxResults = 5,
    this.walkingSpeedKmh = 4.0,
    this.jeepneySpeedKmh = 15.0,
  });

  /// Default configuration
  static const HybridRoutingConfig defaultConfig = HybridRoutingConfig();
}
