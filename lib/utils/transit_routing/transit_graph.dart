import 'package:latlong2/latlong.dart';
import '../../models/jeepney_route.dart';
import 'geo_utils.dart';
import 'models.dart';

/// Builds and manages the jeepney transit network graph
/// Handles route intersections, transfer points, and connectivity
class TransitGraph {
  final HybridRoutingConfig config;
  final List<JeepneyRoute> _routes;
  final List<Map<String, dynamic>>? _landmarks;

  // Cached graph data
  final Map<String, TransitNode> _nodes = {};
  final List<TransitEdge> _edges = [];
  final Map<String, List<TransitEdge>> _adjacencyList = {};

  // Route intersection cache
  List<RouteIntersection>? _intersections;

  TransitGraph({
    required List<JeepneyRoute> routes,
    List<Map<String, dynamic>>? landmarks,
    this.config = HybridRoutingConfig.defaultConfig,
  }) : _routes = routes,
       _landmarks = landmarks;

  /// Initialize the graph by building nodes and edges
  void build() {
    _nodes.clear();
    _edges.clear();
    _adjacencyList.clear();

    // Add route endpoint nodes
    _addRouteEndpoints();

    // Find and add intersection nodes
    _findIntersections();

    // Build edges between nodes
    _buildEdges();
  }

  /// Add start and end points of each route as nodes
  void _addRouteEndpoints() {
    for (final route in _routes) {
      if (route.path.isEmpty) continue;

      // Start node
      final startId = 'endpoint_${route.id}_start';
      _nodes[startId] = TransitNode(
        id: startId,
        location: route.path.first,
        type: TransitNodeType.routeEndpoint,
        name: '${route.routeNumber} Start',
        connectedRouteIds: [route.id.toString()],
      );

      // End node
      final endId = 'endpoint_${route.id}_end';
      _nodes[endId] = TransitNode(
        id: endId,
        location: route.path.last,
        type: TransitNodeType.routeEndpoint,
        name: '${route.routeNumber} End',
        connectedRouteIds: [route.id.toString()],
      );
    }
  }

  /// Find intersections between routes
  void _findIntersections() {
    _intersections = [];

    for (int i = 0; i < _routes.length; i++) {
      for (int j = i + 1; j < _routes.length; j++) {
        final route1 = _routes[i];
        final route2 = _routes[j];

        if (route1.path.isEmpty || route2.path.isEmpty) continue;

        // Quick bounding box check
        if (!GeoUtils.boundingBoxesOverlap(
          route1.path,
          route2.path,
          config.maxTransferWalkingMeters,
        )) {
          continue;
        }

        // Find closest points between the two routes
        final intersection = _findClosestPoints(route1, route2);

        if (intersection != null &&
            intersection.distanceMeters <= config.maxTransferWalkingMeters) {
          _intersections!.add(intersection);

          // Add intersection as a node
          final nodeId =
              'intersection_${route1.id}_${route2.id}_${_intersections!.length}';
          final landmarkName = _findNearbyLandmark(intersection.point);

          _nodes[nodeId] = TransitNode(
            id: nodeId,
            location: intersection.point,
            type: TransitNodeType.intersection,
            name: landmarkName ?? 'Transfer Point',
            connectedRouteIds: [route1.id.toString(), route2.id.toString()],
          );
        }
      }
    }
  }

  /// Find the closest points between two routes
  RouteIntersection? _findClosestPoints(
    JeepneyRoute route1,
    JeepneyRoute route2,
  ) {
    // Sample paths for efficiency
    final sampled1 = GeoUtils.samplePath(route1.path, maxPoints: 30);
    final sampled2 = GeoUtils.samplePath(route2.path, maxPoints: 30);

    double minDistance = double.infinity;
    LatLng? bestPoint1;
    LatLng? bestPoint2;

    for (final p1 in sampled1) {
      for (final p2 in sampled2) {
        final distance = GeoUtils.distanceMeters(p1, p2);
        if (distance < minDistance) {
          minDistance = distance;
          bestPoint1 = p1;
          bestPoint2 = p2;
        }
      }
    }

    if (bestPoint1 == null || bestPoint2 == null) return null;

    // Use midpoint as intersection point
    final midpoint = LatLng(
      (bestPoint1.latitude + bestPoint2.latitude) / 2,
      (bestPoint1.longitude + bestPoint2.longitude) / 2,
    );

    return RouteIntersection(
      route1: route1,
      route2: route2,
      point: midpoint,
      point1OnRoute: bestPoint1,
      point2OnRoute: bestPoint2,
      distanceMeters: minDistance,
    );
  }

  /// Find nearby landmark for a point
  String? _findNearbyLandmark(LatLng point) {
    if (_landmarks == null || _landmarks.isEmpty) return null;

    const maxDistance = 200.0; // meters
    String? nearestName;
    double nearestDistance = double.infinity;

    for (final landmark in _landmarks) {
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

  /// Build edges connecting nodes
  void _buildEdges() {
    // For each route, create edges along its path
    for (final route in _routes) {
      if (route.path.isEmpty) continue;

      // Find all nodes on this route
      final routeNodes = _nodes.values
          .where((n) => n.connectedRouteIds.contains(route.id.toString()))
          .toList();

      // Sort nodes by their position along the route
      routeNodes.sort((a, b) {
        final indexA = GeoUtils.findClosestPointIndex(a.location, route.path);
        final indexB = GeoUtils.findClosestPointIndex(b.location, route.path);
        return indexA.compareTo(indexB);
      });

      // Create edges between consecutive nodes on this route
      for (int i = 0; i < routeNodes.length - 1; i++) {
        final from = routeNodes[i];
        final to = routeNodes[i + 1];

        final distance = GeoUtils.haversineDistance(from.location, to.location);
        final time = GeoUtils.estimateJeepneyTime(distance);

        final edgeId = 'ride_${route.id}_${from.id}_${to.id}';
        final edge = TransitEdge(
          id: edgeId,
          from: from,
          to: to,
          type: TransitEdgeType.jeepneyRide,
          route: route,
          distanceKm: distance,
          estimatedTimeMinutes: time,
          fare: route.baseFare,
        );

        _edges.add(edge);
        _addToAdjacencyList(from.id, edge);

        // Add reverse edge (jeepneys can go both ways conceptually for transfer graph)
        final reverseEdge = TransitEdge(
          id: '${edgeId}_rev',
          from: to,
          to: from,
          type: TransitEdgeType.jeepneyRide,
          route: route,
          distanceKm: distance,
          estimatedTimeMinutes: time,
          fare: route.baseFare,
        );
        _edges.add(reverseEdge);
        _addToAdjacencyList(to.id, reverseEdge);
      }
    }

    // Create walking edges at intersections (transfers)
    if (_intersections != null) {
      for (final intersection in _intersections!) {
        final intersectionNode = _nodes.values.firstWhere(
          (n) =>
              n.type == TransitNodeType.intersection &&
              n.connectedRouteIds.contains(intersection.route1.id.toString()) &&
              n.connectedRouteIds.contains(intersection.route2.id.toString()),
          orElse: () => TransitNode(
            id: 'temp',
            location: intersection.point,
            type: TransitNodeType.intersection,
          ),
        );

        if (intersectionNode.id == 'temp') continue;

        // Walking transfer edge (implicitly handled by being at same node)
        // The walking distance is stored in the intersection
      }
    }
  }

  void _addToAdjacencyList(String nodeId, TransitEdge edge) {
    if (!_adjacencyList.containsKey(nodeId)) {
      _adjacencyList[nodeId] = [];
    }
    _adjacencyList[nodeId]!.add(edge);
  }

  /// Get all routes that pass near a point
  List<RouteAccess> findRoutesNearPoint(LatLng point, {double? maxDistance}) {
    final maxDist = maxDistance ?? config.maxAccessWalkingMeters;
    final results = <RouteAccess>[];

    for (final route in _routes) {
      if (route.path.isEmpty) continue;

      final closestPoint = GeoUtils.findClosestPointOnPath(point, route.path);
      final distance = GeoUtils.distanceMeters(point, closestPoint);

      if (distance <= maxDist) {
        results.add(
          RouteAccess(
            route: route,
            accessPoint: closestPoint,
            walkingDistanceMeters: distance,
            pointIndex: GeoUtils.findClosestPointIndex(
              closestPoint,
              route.path,
            ),
          ),
        );
      }
    }

    // Sort by distance
    results.sort(
      (a, b) => a.walkingDistanceMeters.compareTo(b.walkingDistanceMeters),
    );

    return results;
  }

  /// Get intersections between routes
  List<RouteIntersection> get intersections => _intersections ?? [];

  /// Get all nodes
  Map<String, TransitNode> get nodes => _nodes;

  /// Get all edges
  List<TransitEdge> get edges => _edges;

  /// Get edges from a node
  List<TransitEdge> getEdgesFrom(String nodeId) {
    return _adjacencyList[nodeId] ?? [];
  }

  /// Find intersections where a specific route meets other routes
  List<RouteIntersection> findRouteIntersections(JeepneyRoute route) {
    if (_intersections == null) return [];

    return _intersections!
        .where((i) => i.route1.id == route.id || i.route2.id == route.id)
        .toList();
  }

  /// Get routes that intersect with a given route
  List<JeepneyRoute> findConnectingRoutes(JeepneyRoute route) {
    final connecting = <JeepneyRoute>{};

    for (final intersection in findRouteIntersections(route)) {
      if (intersection.route1.id == route.id) {
        connecting.add(intersection.route2);
      } else {
        connecting.add(intersection.route1);
      }
    }

    return connecting.toList();
  }
}

/// Represents an intersection between two routes
class RouteIntersection {
  final JeepneyRoute route1;
  final JeepneyRoute route2;
  final LatLng point;
  final LatLng point1OnRoute;
  final LatLng point2OnRoute;
  final double distanceMeters;

  RouteIntersection({
    required this.route1,
    required this.route2,
    required this.point,
    required this.point1OnRoute,
    required this.point2OnRoute,
    required this.distanceMeters,
  });

  @override
  String toString() =>
      'RouteIntersection(${route1.routeNumber} <-> ${route2.routeNumber}, ${distanceMeters.toStringAsFixed(0)}m)';
}

/// Represents access to a route from a point
class RouteAccess {
  final JeepneyRoute route;
  final LatLng accessPoint;
  final double walkingDistanceMeters;
  final int pointIndex; // Index along the route path

  RouteAccess({
    required this.route,
    required this.accessPoint,
    required this.walkingDistanceMeters,
    required this.pointIndex,
  });

  @override
  String toString() =>
      'RouteAccess(${route.routeNumber}, walk: ${walkingDistanceMeters.toStringAsFixed(0)}m)';
}
