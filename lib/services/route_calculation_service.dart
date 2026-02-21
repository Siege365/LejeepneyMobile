import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../models/jeepney_route.dart';
import '../utils/multi_transfer_matcher.dart';
import '../utils/route_matcher.dart';
import '../utils/transit_routing/transit_routing.dart';
import 'api_service.dart';
import 'app_data_preloader.dart';

/// Service responsible for calculating routes and matching jeepney routes.
///
/// Strategy: **Server-first with local fallback.**
/// 1. Try server `findRoutesV2()` — fastest, supports multi-transfer
/// 2. If server fails, fall back to local `HybridTransitRouter` (pre-built graph)
/// 3. Legacy `RouteMatcher`/`MultiTransferMatcher` still run for OSRM path matching
class RouteCalculationService {
  final ApiService _apiService = ApiService();

  RouteCalculationService();

  /// Calculate routes between two points.
  ///
  /// Tries the server API first for speed and multi-transfer support.
  /// Falls back to local graph-based routing if the server is unreachable.
  Future<RouteCalculationResult> calculateRoutes({
    required LatLng origin,
    required LatLng destination,
    List<LatLng>? osrmPath,
  }) async {
    final stopwatch = Stopwatch()..start();

    // === Phase 1: Try server-side route finding ===
    try {
      final serverRoutes = await _apiService.findRoutesV2(
        fromLat: origin.latitude,
        fromLng: origin.longitude,
        toLat: destination.latitude,
        toLng: destination.longitude,
      );

      if (serverRoutes.isNotEmpty) {
        final calculatedFare = serverRoutes.first.totalFare;

        stopwatch.stop();
        debugPrint(
          '[RouteCalcService] Server returned ${serverRoutes.length} routes '
          'in ${stopwatch.elapsedMilliseconds}ms',
        );

        return RouteCalculationResult(
          success: true,
          calculatedFare: calculatedFare,
          legacyMatches: [],
          legacyMultiTransfer: [],
          hybridSuggestedRoutes: serverRoutes,
          hybridResult: null, // Not from local hybrid router
          fromServer: true,
        );
      }

      debugPrint(
        '[RouteCalcService] Server returned 0 routes, falling back to local',
      );
    } catch (e) {
      debugPrint(
        '[RouteCalcService] Server routing failed: $e — falling back to local',
      );
    }

    // === Phase 2: Local fallback (pre-built graph) ===
    try {
      final preloader = AppDataPreloader.instance;

      // Ensure the transit graph is ready (may still be building in background)
      await preloader.ensureGraphReady();

      final hybridRouter = preloader.hybridRouter;

      // Use pre-loaded routes (no API call needed)
      final jeepneyRoutes = preloader.cachedRoutes;
      final landmarks = preloader.cachedLandmarkMaps;

      debugPrint(
        '[RouteCalcService] Local fallback: ${jeepneyRoutes.length} pre-loaded routes, '
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
        '[RouteCalcService] Local result: ${hybridResult.suggestedRoutes.length} routes',
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
        '[RouteCalcService] Local calculation done in ${stopwatch.elapsedMilliseconds}ms',
      );

      return RouteCalculationResult(
        success: true,
        calculatedFare: calculatedFare,
        legacyMatches: legacyMatches,
        legacyMultiTransfer: legacyMultiTransfer,
        hybridSuggestedRoutes: hybridResult.suggestedRoutes,
        hybridResult: hybridResult,
        fromServer: false,
      );
    } catch (e, stackTrace) {
      debugPrint('Error calculating routes: $e');
      debugPrint('Stack trace: $stackTrace');

      // Provide user-friendly error message
      String userMessage;
      if (e.toString().contains('SocketException') ||
          e.toString().contains('HandshakeException') ||
          e.toString().contains('Connection refused')) {
        userMessage =
            'No internet connection. Route calculation requires '
            'cached route data — please connect to WiFi at least once.';
      } else {
        userMessage = 'Unable to calculate routes. Please try again.';
      }

      return RouteCalculationResult(
        success: false,
        errorMessage: userMessage,
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
  final bool fromServer; // Whether results came from server API

  RouteCalculationResult({
    required this.success,
    this.errorMessage,
    required this.calculatedFare,
    required this.legacyMatches,
    required this.legacyMultiTransfer,
    required this.hybridSuggestedRoutes,
    this.hybridResult,
    this.fromServer = false,
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
