// Route Repository
// Manages jeepney route data with offline-first disk persistence.
// Load order: memory cache → SQLite disk → API (with background sync).

import 'package:flutter/foundation.dart';
import '../database/route_storage.dart';
import '../models/jeepney_route.dart';
import '../services/api_service.dart';
import 'base_repository.dart';

class RouteRepository extends BaseRepository<List<JeepneyRoute>> {
  final ApiService _apiService;
  final RouteStorage _storage = RouteStorage();

  // State
  List<JeepneyRoute> _routes = [];
  bool _isLoading = false;
  String? _error;
  bool _isOfflineData = false; // true when serving disk-only data
  bool _isSyncing = false; // true during background API sync
  DateTime? _lastSyncTime;

  // Cache keys
  static const String _allRoutesKey = 'all_routes';

  // Background sync interval — don't re-sync if synced within this window
  static const Duration _syncCooldown = Duration(minutes: 10);

  RouteRepository({ApiService? apiService})
    : _apiService = apiService ?? ApiService();

  // Getters
  List<JeepneyRoute> get routes => List.unmodifiable(_routes);
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasRoutes => _routes.isNotEmpty;
  bool get isOfflineData => _isOfflineData;
  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;

  /// Fetch all routes — offline-first strategy:
  /// 1. Return memory cache if valid
  /// 2. Load from SQLite disk instantly
  /// 3. Sync with API in background (or foreground if disk is empty)
  Future<Result<List<JeepneyRoute>>> fetchAllRoutes({
    bool forceRefresh = false,
  }) async {
    // ── Step 1: Memory cache (instant) ──
    if (!forceRefresh && isCacheValid(_allRoutesKey)) {
      final cached = getCached(_allRoutesKey);
      if (cached != null && cached.isNotEmpty) {
        _routes = cached;
        notifyListeners();
        // Still kick off background sync if cooldown expired
        _maybeSyncInBackground();
        return Result.success(cached);
      }
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    // ── Step 2: SQLite disk (fast, ~50ms for 50 routes) ──
    List<JeepneyRoute>? diskRoutes;
    try {
      final hasStored = await _storage.hasStoredRoutes();
      if (hasStored) {
        diskRoutes = await _storage.loadRoutes();
        _lastSyncTime = await _storage.getLastSyncTime();
        debugPrint(
          '[RouteRepo] Loaded ${diskRoutes.length} routes from disk'
          ' (synced: $_lastSyncTime)',
        );
      }
    } catch (e) {
      debugPrint('[RouteRepo] Disk load failed: $e');
    }

    // If we have disk data, serve it immediately
    if (diskRoutes != null && diskRoutes.isNotEmpty) {
      _routes = diskRoutes;
      _isOfflineData = true;
      setCache(_allRoutesKey, diskRoutes);
      _isLoading = false;
      notifyListeners();

      // Background sync with API (non-blocking)
      if (forceRefresh) {
        // Force refresh: do foreground sync so caller awaits fresh data
        return await _syncFromApi();
      } else {
        _maybeSyncInBackground();
        return Result.success(diskRoutes);
      }
    }

    // ── Step 3: No disk data — must fetch from API (first launch) ──
    debugPrint('[RouteRepo] No disk data, fetching from API...');
    return await _syncFromApi();
  }

  /// Foreground API sync — fetches routes, persists to disk, updates state.
  /// Returns Result so caller knows if it succeeded.
  Future<Result<List<JeepneyRoute>>> _syncFromApi() async {
    _isSyncing = true;
    notifyListeners();

    try {
      final routes = await _apiService.fetchAllRoutes();
      routes.sort((a, b) => a.name.compareTo(b.name));

      // Persist to SQLite
      await _persistRoutes(routes);

      _routes = routes;
      _isOfflineData = false;
      _isSyncing = false;
      _isLoading = false;
      _error = null;
      setCache(_allRoutesKey, routes);
      notifyListeners();

      debugPrint('[RouteRepo] API sync complete: ${routes.length} routes');
      return Result.success(routes);
    } catch (e) {
      _isSyncing = false;
      _isLoading = false;
      debugPrint('[RouteRepo] API sync failed: $e');

      // If we already have routes (from disk), keep them — not an error
      if (_routes.isNotEmpty) {
        _isOfflineData = true;
        _error = null;
        notifyListeners();
        return Result.success(_routes);
      }

      // No routes at all — genuine failure
      _error = 'No routes available. Connect to the internet for first sync.';
      notifyListeners();
      return Result.failure(_error!);
    }
  }

  /// Background sync — non-blocking, respects cooldown.
  void _maybeSyncInBackground() {
    if (_isSyncing) return;

    // Respect cooldown
    if (_lastSyncTime != null) {
      final elapsed = DateTime.now().difference(_lastSyncTime!);
      if (elapsed < _syncCooldown) {
        debugPrint(
          '[RouteRepo] Sync cooldown active '
          '(${elapsed.inMinutes}m / ${_syncCooldown.inMinutes}m)',
        );
        return;
      }
    }

    debugPrint('[RouteRepo] Starting background sync...');
    _syncFromApi(); // fire-and-forget
  }

  /// Persist routes to SQLite and update sync timestamp.
  Future<void> _persistRoutes(List<JeepneyRoute> routes) async {
    try {
      await _storage.saveRoutes(routes);
      _lastSyncTime = DateTime.now();
      debugPrint('[RouteRepo] Persisted ${routes.length} routes to disk');
    } catch (e) {
      debugPrint('[RouteRepo] Failed to persist routes: $e');
      // Non-fatal — routes are still in memory
    }
  }

  /// Fetch a single route by ID
  Future<Result<JeepneyRoute>> fetchRouteById(int id) async {
    // Check if already in memory
    try {
      final existing = _routes.firstWhere((r) => r.id == id);
      return Result.success(existing);
    } catch (_) {
      // Not found in memory, fetch from API
    }

    try {
      final route = await _apiService.fetchRouteById(id);
      return Result.success(route);
    } catch (e) {
      return Result.failure(e.toString());
    }
  }

  /// Get route by ID from memory (no API call)
  JeepneyRoute? getRouteById(int id) {
    try {
      return _routes.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Get routes by IDs
  List<JeepneyRoute> getRoutesByIds(List<int> ids) {
    return _routes.where((r) => ids.contains(r.id)).toList();
  }

  /// Search routes by name or number
  List<JeepneyRoute> searchRoutes(String query) {
    if (query.isEmpty) return _routes;

    final lowercaseQuery = query.toLowerCase();
    return _routes.where((route) {
      final description = route.description?.toLowerCase() ?? '';
      return route.name.toLowerCase().contains(lowercaseQuery) ||
          route.routeNumber.toLowerCase().contains(lowercaseQuery) ||
          description.contains(lowercaseQuery);
    }).toList();
  }

  /// Filter routes by area coverage
  List<JeepneyRoute> filterByArea(String area) {
    final lowercaseArea = area.toLowerCase();
    return _routes.where((route) {
      final terminal = route.terminal?.toLowerCase() ?? '';
      final destination = route.destination?.toLowerCase() ?? '';
      final description = route.description?.toLowerCase() ?? '';
      return terminal.contains(lowercaseArea) ||
          destination.contains(lowercaseArea) ||
          description.contains(lowercaseArea);
    }).toList();
  }

  /// Refresh routes (force fetch from API)
  Future<void> refresh() async {
    await fetchAllRoutes(forceRefresh: true);
  }

  /// Clear all data including disk storage
  void clear() {
    _routes = [];
    _error = null;
    _isOfflineData = false;
    clearAllCache();
    notifyListeners();
    // Also clear disk in background
    _storage.deleteAllRoutes().catchError((e) {
      debugPrint('[RouteRepo] Failed to clear disk: $e');
    });
  }

  /// Get sync status info for UI display
  Map<String, dynamic> get syncStatus => {
    'routeCount': _routes.length,
    'isOfflineData': _isOfflineData,
    'isSyncing': _isSyncing,
    'lastSyncTime': _lastSyncTime?.toIso8601String(),
    'hasError': _error != null,
  };
}
