import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../models/jeepney_route.dart';
import '../utils/multi_transfer_matcher.dart';
import '../utils/route_matcher.dart';
import '../utils/transit_routing/transit_routing.dart';
import 'api_service.dart';

/// Service responsible for calculating routes and matching jeepney routes
/// Follows Single Responsibility Principle - only handles route calculation logic
class RouteCalculationService {
  final ApiService _apiService;
  final HybridTransitRouter _hybridRouter;

  RouteCalculationService({
    required ApiService apiService,
    HybridTransitRouter? hybridRouter,
  }) : _apiService = apiService,
       _hybridRouter =
           hybridRouter ??
           HybridTransitRouter(
             config: const HybridRoutingConfig(maxResults: 5, maxTransfers: 3),
           );

  /// Calculate routes between two points
  /// Returns a RouteCalculationResult with all matched routes
  Future<RouteCalculationResult> calculateRoutes({
    required LatLng origin,
    required LatLng destination,
    List<LatLng>? osrmPath,
  }) async {
    try {
      // Fetch all admin-created jeepney routes from API
      final jeepneyRoutes = await _apiService.fetchAllRoutes();

      // Fetch landmarks for transfer point identification
      List<Map<String, dynamic>>? landmarks;
      try {
        final landmarkData = await _apiService.fetchAllLandmarks();
        landmarks = landmarkData
            .map(
              (l) => {
                'id': l.id,
                'name': l.name,
                'latitude': l.latitude,
                'longitude': l.longitude,
              },
            )
            .toList();
      } catch (e) {
        debugPrint('Failed to fetch landmarks for transfer points: $e');
      }

      // Pre-initialize router graph in background to avoid blocking UI
      debugPrint('[RouteCalcService] Pre-initializing hybrid router...');
      await _hybridRouter.preInitialize(
        routes: jeepneyRoutes,
        landmarks: landmarks,
      );
      debugPrint('[RouteCalcService] Hybrid router ready');

      // Use hybrid router for best results
      final hybridResult = await _hybridRouter.findRoutes(
        origin: origin,
        destination: destination,
        jeepneyRoutes: jeepneyRoutes,
        osrmPath: osrmPath,
        landmarks: landmarks,
      );

      debugPrint('Hybrid routing result: ${hybridResult.toString()}');
      debugPrint('  - Routes found: ${hybridResult.suggestedRoutes.length}');

      // Also do legacy matching for backward compatibility
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

      // Calculate fare from hybrid result
      final calculatedFare = hybridResult.suggestedRoutes.isNotEmpty
          ? hybridResult.suggestedRoutes.first.totalFare
          : 0.0;

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
