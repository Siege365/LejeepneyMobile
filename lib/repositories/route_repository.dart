// Route Repository
// Manages jeepney route data with caching and state management

import '../models/jeepney_route.dart';
import '../services/api_service.dart';
import 'base_repository.dart';

class RouteRepository extends BaseRepository<List<JeepneyRoute>> {
  final ApiService _apiService;

  // State
  List<JeepneyRoute> _routes = [];
  bool _isLoading = false;
  String? _error;

  // Cache keys
  static const String _allRoutesKey = 'all_routes';

  RouteRepository({ApiService? apiService})
    : _apiService = apiService ?? ApiService();

  // Getters
  List<JeepneyRoute> get routes => List.unmodifiable(_routes);
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasRoutes => _routes.isNotEmpty;

  /// Fetch all routes with caching
  Future<Result<List<JeepneyRoute>>> fetchAllRoutes({
    bool forceRefresh = false,
  }) async {
    // Check cache first
    if (!forceRefresh && isCacheValid(_allRoutesKey)) {
      final cached = getCached(_allRoutesKey);
      if (cached != null) {
        _routes = cached;
        notifyListeners();
        return Result.success(cached);
      }
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final routes = await _apiService.fetchAllRoutes();

      // Sort alphabetically
      routes.sort((a, b) => a.name.compareTo(b.name));

      _routes = routes;
      setCache(_allRoutesKey, routes);
      _isLoading = false;
      notifyListeners();

      return Result.success(routes);
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      return Result.failure(e.toString());
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

  /// Clear all data
  void clear() {
    _routes = [];
    _error = null;
    clearAllCache();
    notifyListeners();
  }
}
