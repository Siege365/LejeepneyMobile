import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../models/jeepney_route.dart';
import '../utils/multi_transfer_matcher.dart';
import '../utils/route_matcher.dart';
import '../utils/transit_routing/transit_routing.dart';
import 'app_data_preloader.dart';

/// Service responsible for calculating routes and matching jeepney routes.
/// Uses pre-loaded data from AppDataPreloader for instant calculations
/// instead of re-fetching routes/landmarks from API every time.
class RouteCalculationService {
  RouteCalculationService();

  /// Calculate routes between two points using pre-loaded data.
  /// The hybrid router and route data are already cached by AppDataPreloader,
  /// so this skips all network calls and graph rebuilds.
  Future<RouteCalculationResult> calculateRoutes({
    required LatLng origin,
    required LatLng destination,
    List<LatLng>? osrmPath,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      final preloader = AppDataPreloader.instance;
      final hybridRouter = preloader.hybridRouter;

      // Use pre-loaded routes (no API call needed)
      final jeepneyRoutes = preloader.cachedRoutes;
      final landmarks = preloader.cachedLandmarkMaps;

      debugPrint(
        '[RouteCalcService] Using ${jeepneyRoutes.length} pre-loaded routes, '
        '${landmarks?.length ?? 0} landmarks',
      );

      // Use hybrid router for best results (graph already pre-built)
      final hybridResult = await hybridRouter.findRoutes(
        origin: origin,
        destination: destination,
        jeepneyRoutes: jeepneyRoutes,
        osrmPath: osrmPath,
        landmarks: landmarks,
      );

      debugPrint(
        '[RouteCalcService] Hybrid result: ${hybridResult.suggestedRoutes.length} routes',
      );

      // Legacy matching for backward compatibility (only if OSRM path exists)
      List<RouteMatchResult> legacyMatches = [];
      List<MultiTransferRoute> legacyMultiTransfer = [];

      if (osrmPath != null && osrmPath.isNotEmpty) {
        legacyMatches = RouteMatcher.findMatchingRoutes(
          userPath: osrmPath,
          jeepneyRoutes: jeepneyRoutes,
          bufferMeters: 150.0,
          minMatchPercentage: 50.0,
          maxCount: 5,
        );

        if (legacyMatches.isEmpty || legacyMatches.length < 2) {
          legacyMultiTransfer = MultiTransferMatcher.findMultiTransferRoutes(
            userPath: osrmPath,
            jeepneyRoutes: jeepneyRoutes,
            landmarks: landmarks,
            maxResults: 5,
          );
        }
      }

      final calculatedFare = hybridResult.suggestedRoutes.isNotEmpty
          ? hybridResult.suggestedRoutes.first.totalFare
          : 0.0;

      stopwatch.stop();
      debugPrint(
        '[RouteCalcService] Calculation done in ${stopwatch.elapsedMilliseconds}ms',
      );

      return RouteCalculationResult(
        success: true,
        calculatedFare: calculatedFare,
        legacyMatches: legacyMatches,
        legacyMultiTransfer: legacyMultiTransfer,
        hybridSuggestedRoutes: hybridResult.suggestedRoutes,
        hybridResult: hybridResult,
      );
    } catch (e, stackTrace) {
      debugPrint('Error calculating routes: $e');
      debugPrint('Stack trace: $stackTrace');
      return RouteCalculationResult(
        success: false,
        errorMessage: e.toString(),
        calculatedFare: 0.0,
        legacyMatches: [],
        legacyMultiTransfer: [],
        hybridSuggestedRoutes: [],
      );
    }
  }
}

/// Result of route calculation
/// Type-safe result wrapper (no dynamic)
class RouteCalculationResult {
  final bool success;
  final String? errorMessage;
  final double calculatedFare;
  final List<RouteMatchResult> legacyMatches;
  final List<MultiTransferRoute> legacyMultiTransfer;
  final List<SuggestedRoute> hybridSuggestedRoutes;
  final HybridRoutingResult? hybridResult;

  RouteCalculationResult({
    required this.success,
    this.errorMessage,
    required this.calculatedFare,
    required this.legacyMatches,
    required this.legacyMultiTransfer,
    required this.hybridSuggestedRoutes,
    this.hybridResult,
  });

  Map<int, double> get routeMatchPercentages {
    final Map<int, double> percentages = {};
    for (var match in legacyMatches) {
      percentages[match.route.id] = match.matchPercentage;
    }
    return percentages;
  }

  List<JeepneyRoute> get suggestedRoutes {
    return legacyMatches.map((match) => match.route).toList();
  }
}
