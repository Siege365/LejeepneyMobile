// App Data Preloader
// Centralizes data pre-loading during splash screen so screens
// can access cached data instantly without waiting for API calls.
//
// Loads in parallel: routes, landmarks, auth, fare settings.
// Pre-builds transit routing graph for fast direction calculations.

import 'package:flutter/foundation.dart';
import '../repositories/repositories.dart';
import '../models/jeepney_route.dart';
import '../utils/transit_routing/transit_routing.dart';
import 'fare_settings_service.dart';

/// Singleton service that pre-loads all app data during splash.
/// Screens read from repositories (cached) instead of calling APIs directly.
class AppDataPreloader {
  AppDataPreloader._();
  static final AppDataPreloader instance = AppDataPreloader._();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // Repository references for cached data access
  RouteRepository? _routeRepo;
  LandmarkRepository? _landmarkRepo;

  // Shared transit router with pre-built graph
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
  /// Navigation-critical data loads first; transit graph builds in background.
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

    // Pre-build transit graph in the BACKGROUND (non-blocking)
    // User can navigate immediately; graph will be ready by the time they need it
    if (routeRepository.hasRoutes) {
      _graphBuildFuture = _buildTransitGraph(routeRepository.routes).then((_) {
        debugPrint(
          '[AppDataPreloader] Total including graph: ${stopwatch.elapsedMilliseconds}ms',
        );
        _graphBuildFuture = null;
      });
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
