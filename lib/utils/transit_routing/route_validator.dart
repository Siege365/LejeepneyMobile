import 'package:latlong2/latlong.dart';
import '../../models/jeepney_route.dart';
import 'geo_utils.dart';
import 'models.dart';

/// Validates OSRM-generated routes against jeepney route data
/// Determines if the OSRM path has sufficient jeepney coverage
class RouteAccuracyValidator {
  final HybridRoutingConfig config;

  RouteAccuracyValidator({this.config = HybridRoutingConfig.defaultConfig});

  /// Validate an OSRM-generated path against available jeepney routes
  /// Returns validation result with coverage details
  RouteValidationResult validate({
    required List<LatLng> osrmPath,
    required List<JeepneyRoute> jeepneyRoutes,
  }) {
    if (osrmPath.isEmpty) {
      return RouteValidationResult(
        isAccurate: false,
        coveragePercentage: 0.0,
        maxGapMeters: 0.0,
        uncoveredSegments: [],
        reason: 'Empty OSRM path',
      );
    }

    if (jeepneyRoutes.isEmpty) {
      return RouteValidationResult(
        isAccurate: false,
        coveragePercentage: 0.0,
        maxGapMeters: 0.0,
        uncoveredSegments: osrmPath,
        reason: 'No jeepney routes available',
      );
    }

    // Sample path for efficiency
    final sampledPath = GeoUtils.samplePath(osrmPath, maxPoints: 100);

    // Check coverage for each point
    final coverageResults = _analyzeCoverage(sampledPath, jeepneyRoutes);

    // Calculate overall coverage percentage
    final coveragePercentage =
        coverageResults.coveredPointCount / sampledPath.length * 100;

    // Find maximum gap in coverage
    final maxGap = _findMaxGap(sampledPath, coverageResults.coveredPoints);

    // Determine if route is accurate
    final isAccurate =
        coveragePercentage >= config.minCoveragePercentage &&
        maxGap <= config.maxCoverageGapMeters;

    String reason;
    if (isAccurate) {
      reason = 'Route has sufficient jeepney coverage';
    } else if (coveragePercentage < config.minCoveragePercentage) {
      reason =
          'Only ${coveragePercentage.toStringAsFixed(1)}% of path covered by jeepney routes (minimum: ${config.minCoveragePercentage}%)';
    } else {
      reason =
          'Gap of ${maxGap.toStringAsFixed(0)}m without jeepney coverage (maximum: ${config.maxCoverageGapMeters}m)';
    }

    return RouteValidationResult(
      isAccurate: isAccurate,
      coveragePercentage: coveragePercentage,
      maxGapMeters: maxGap,
      uncoveredSegments: coverageResults.uncoveredPoints,
      reason: reason,
    );
  }

  /// Analyze which points are covered by jeepney routes
  _CoverageAnalysis _analyzeCoverage(
    List<LatLng> path,
    List<JeepneyRoute> routes,
  ) {
    final coveredPoints = <int>[];
    final uncoveredPoints = <LatLng>[];
    int coveredCount = 0;

    // Buffer distance for considering a point "covered"
    const bufferMeters = 150.0;

    for (int i = 0; i < path.length; i++) {
      final point = path[i];
      bool isCovered = false;

      for (final route in routes) {
        if (route.path.isEmpty) continue;

        final distance = GeoUtils.minDistanceToPath(point, route.path);
        if (distance <= bufferMeters) {
          isCovered = true;
          break;
        }
      }

      if (isCovered) {
        coveredPoints.add(i);
        coveredCount++;
      } else {
        uncoveredPoints.add(point);
      }
    }

    return _CoverageAnalysis(
      coveredPointCount: coveredCount,
      coveredPoints: coveredPoints,
      uncoveredPoints: uncoveredPoints,
    );
  }

  /// Find the maximum gap in coverage (consecutive uncovered distance)
  double _findMaxGap(List<LatLng> path, List<int> coveredIndices) {
    if (coveredIndices.isEmpty) {
      return GeoUtils.pathLength(path) * 1000; // All uncovered
    }

    final coveredSet = coveredIndices.toSet();
    double maxGap = 0.0;
    double currentGap = 0.0;
    int gapStartIndex = -1;

    for (int i = 0; i < path.length; i++) {
      if (!coveredSet.contains(i)) {
        // Start or continue a gap
        if (gapStartIndex == -1) {
          gapStartIndex = i;
        }
        if (i < path.length - 1) {
          currentGap += GeoUtils.distanceMeters(path[i], path[i + 1]);
        }
      } else {
        // End of a gap
        if (currentGap > maxGap) {
          maxGap = currentGap;
        }
        currentGap = 0.0;
        gapStartIndex = -1;
      }
    }

    // Check if path ends with a gap
    if (currentGap > maxGap) {
      maxGap = currentGap;
    }

    return maxGap;
  }

  /// Check if a specific segment of the path has jeepney coverage
  bool hasSegmentCoverage({
    required List<LatLng> segment,
    required List<JeepneyRoute> routes,
    double minCoveragePercent = 50.0,
  }) {
    if (segment.isEmpty) return false;

    final result = validate(osrmPath: segment, jeepneyRoutes: routes);
    return result.coveragePercentage >= minCoveragePercent;
  }

  /// Find which routes cover a specific point
  List<JeepneyRoute> findCoveringRoutes({
    required LatLng point,
    required List<JeepneyRoute> routes,
    double bufferMeters = 300.0,
  }) {
    final coveringRoutes = <JeepneyRoute>[];

    for (final route in routes) {
      if (route.path.isEmpty) continue;

      final distance = GeoUtils.minDistanceToPath(point, route.path);
      if (distance <= bufferMeters) {
        coveringRoutes.add(route);
      }
    }

    // Sort by distance (closest first)
    coveringRoutes.sort((a, b) {
      final distA = GeoUtils.minDistanceToPath(point, a.path);
      final distB = GeoUtils.minDistanceToPath(point, b.path);
      return distA.compareTo(distB);
    });

    return coveringRoutes;
  }

  /// Get coverage analysis with per-route breakdown
  Map<String, dynamic> getDetailedCoverageAnalysis({
    required List<LatLng> path,
    required List<JeepneyRoute> routes,
  }) {
    final routeCoverage = <String, double>{};
    final sampledPath = GeoUtils.samplePath(path, maxPoints: 50);

    for (final route in routes) {
      if (route.path.isEmpty) continue;

      int coveredCount = 0;
      for (final point in sampledPath) {
        final distance = GeoUtils.minDistanceToPath(point, route.path);
        if (distance <= 150.0) {
          coveredCount++;
        }
      }

      final coverage = coveredCount / sampledPath.length * 100;
      if (coverage > 0) {
        routeCoverage[route.id.toString()] = coverage;
      }
    }

    // Sort by coverage (highest first)
    final sortedRoutes = routeCoverage.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return {
      'totalPathPoints': sampledPath.length,
      'routeCoverage': Map.fromEntries(sortedRoutes),
      'bestRoute': sortedRoutes.isNotEmpty ? sortedRoutes.first.key : null,
      'bestCoverage': sortedRoutes.isNotEmpty ? sortedRoutes.first.value : 0.0,
    };
  }
}

class _CoverageAnalysis {
  final int coveredPointCount;
  final List<int> coveredPoints;
  final List<LatLng> uncoveredPoints;

  _CoverageAnalysis({
    required this.coveredPointCount,
    required this.coveredPoints,
    required this.uncoveredPoints,
  });
}
