// App Data Preloader
// Centralizes data pre-loading during splash screen so screens
// can access cached data instantly without waiting for API calls.
//
// Loads in parallel: routes, landmarks, auth, fare settings.
// Transit graph is built lazily (on first local routing request)
// since server-side routing is tried first.

import 'package:flutter/foundation.dart';
import '../repositories/repositories.dart';
import '../models/jeepney_route.dart';
import '../utils/transit_routing/transit_routing.dart';
import 'api_service.dart';
import 'fare_settings_service.dart';

/// Singleton service that pre-loads all app data during splash.
/// Screens read from repositories (cached) instead of calling APIs directly.
class AppDataPreloader {
  AppDataPreloader._();
  static final AppDataPreloader instance = AppDataPreloader._();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // Whether server routing is available (checked during init)
  bool _serverRoutingAvailable = false;
  bool get serverRoutingAvailable => _serverRoutingAvailable;

  // Repository references for cached data access
  RouteRepository? _routeRepo;
  LandmarkRepository? _landmarkRepo;

  // Shared transit router with pre-built graph (lazy)
  HybridTransitRouter? _hybridRouter;
  Future<void>? _graphBuildFuture;

  HybridTransitRouter get hybridRouter =>
      _hybridRouter ??
      HybridTransitRouter(
        config: const HybridRoutingConfig(maxResults: 5, maxTransfers: 2),
      );

  /// Wait for the background graph build to finish (if still running)
  Future<void> ensureGraphReady() async {
    if (_graphBuildFuture != null) {
      await _graphBuildFuture;
      return;
    }

    // If graph hasn't been built yet, build it now (lazy init)
    if (_hybridRouter == null && (_routeRepo?.hasRoutes ?? false)) {
      debugPrint('[AppDataPreloader] Lazy-building transit graph...');
      await _buildTransitGraph(_routeRepo!.routes);
    }
  }

  /// Pre-loaded jeepney routes (avoids API calls in RouteCalculationService)
  List<JeepneyRoute> get cachedRoutes => _routeRepo?.routes ?? [];

  /// Pre-loaded landmarks as Map format for transit routing
  List<Map<String, dynamic>>? get cachedLandmarkMaps {
    final landmarks = _landmarkRepo?.landmarks;
    if (landmarks == null || landmarks.isEmpty) return null;
    return landmarks
        .map(
          (l) => {
            'id': l.id,
            'name': l.name,
            'latitude': l.latitude,
            'longitude': l.longitude,
          },
        )
        .toList();
  }

  /// Pre-load all critical data in parallel.
  /// Called once during splash screen.
  /// Navigation-critical data loads first; transit graph is deferred.
  Future<void> initialize({
    required RouteRepository routeRepository,
    required LandmarkRepository landmarkRepository,
    required AuthRepository authRepository,
  }) async {
    if (_isInitialized) return;

    // Store references for cached data access
    _routeRepo = routeRepository;
    _landmarkRepo = landmarkRepository;

    final stopwatch = Stopwatch()..start();

    // Run all data fetches in parallel with a timeout
    // If API is slow, proceed anyway after 8 seconds
    await Future.wait([
      _loadRoutes(routeRepository),
      _loadLandmarks(landmarkRepository),
      _loadAuth(authRepository),
      _loadFareSettings(),
    ]).timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        debugPrint(
          '[AppDataPreloader] Timeout reached — proceeding with whatever loaded',
        );
        return [null, null, null, null];
      },
    );

    _isInitialized = true;
    debugPrint(
      '[AppDataPreloader] Critical data loaded in ${stopwatch.elapsedMilliseconds}ms',
    );

    // Check if server routing is available (quick health check)
    await _checkServerRouting();

    // Only pre-build transit graph if server routing is NOT available.
    // If server routing works, graph is built lazily on first local fallback.
    if (!_serverRoutingAvailable && routeRepository.hasRoutes) {
      debugPrint(
        '[AppDataPreloader] Server routing unavailable — building transit graph',
      );
      _graphBuildFuture = _buildTransitGraph(routeRepository.routes).then((_) {
        debugPrint(
          '[AppDataPreloader] Total including graph: ${stopwatch.elapsedMilliseconds}ms',
        );
        _graphBuildFuture = null;
      });
    } else {
      debugPrint(
        '[AppDataPreloader] Server routing available — skipping graph pre-build '
        '(will lazy-build if needed)',
      );
    }
  }

  /// Quick check if the server's route-finding endpoint is reachable.
  /// Non-blocking — sets the flag for future use.
  Future<void> _checkServerRouting() async {
    try {
      final isReachable = await ApiService().healthCheck();
      _serverRoutingAvailable = isReachable;
      debugPrint(
        '[AppDataPreloader] Server routing: ${isReachable ? "available" : "unavailable"}',
      );
    } catch (e) {
      _serverRoutingAvailable = false;
      debugPrint('[AppDataPreloader] Server check failed: $e');
    }
  }

  Future<void> _loadRoutes(RouteRepository repo) async {
    try {
      final result = await repo.fetchAllRoutes();
      if (result.isSuccess) {
        debugPrint('[AppDataPreloader] Routes loaded: ${repo.routes.length}');
      } else {
        debugPrint('[AppDataPreloader] Routes failed: ${result.error}');
      }
    } catch (e) {
      debugPrint('[AppDataPreloader] Routes error: $e');
    }
  }

  Future<void> _loadLandmarks(LandmarkRepository repo) async {
    try {
      final result = await repo.fetchAllLandmarks();
      if (result.isSuccess) {
        debugPrint(
          '[AppDataPreloader] Landmarks loaded: ${repo.landmarks.length}',
        );
      } else {
        debugPrint('[AppDataPreloader] Landmarks failed: ${result.error}');
      }
    } catch (e) {
      debugPrint('[AppDataPreloader] Landmarks error: $e');
    }
  }

  Future<void> _loadAuth(AuthRepository repo) async {
    try {
      await repo.initialize();
      debugPrint('[AppDataPreloader] Auth initialized: ${repo.state}');
    } catch (e) {
      debugPrint('[AppDataPreloader] Auth error: $e');
    }
  }

  Future<void> _loadFareSettings() async {
    try {
      await FareSettingsService.instance.initialize();
      debugPrint('[AppDataPreloader] Fare settings loaded');
    } catch (e) {
      debugPrint('[AppDataPreloader] Fare settings error: $e');
    }
  }

  Future<void> _buildTransitGraph(List<JeepneyRoute> routes) async {
    try {
      _hybridRouter = HybridTransitRouter(
        config: const HybridRoutingConfig(maxResults: 5, maxTransfers: 2),
      );
      await _hybridRouter!.preInitialize(routes: routes);
      debugPrint('[AppDataPreloader] Transit graph pre-built');
    } catch (e) {
      debugPrint('[AppDataPreloader] Transit graph error: $e');
    }
  }
}
