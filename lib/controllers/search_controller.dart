// Search Controller
// Manages state and business logic for search and route finding

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/jeepney_route.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../utils/transit_routing/transit_routing.dart';

/// Search result from place search
class PlaceResult {
  final String name;
  final double lat;
  final double lon;
  final String type;

  PlaceResult({
    required this.name,
    required this.lat,
    required this.lon,
    this.type = '',
  });

  LatLng get location => LatLng(lat, lon);
}

/// Controller for search screen logic
class SearchController extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final LocationService _locationService = LocationService();
  final HybridTransitRouter _hybridRouter;

  // Location state
  LatLng? _currentLocation;
  bool _isLoadingLocation = true;
  String _locationStatus = 'Getting your location...';
  String _currentAddress = 'Davao City, Philippines';

  // Search state
  List<PlaceResult> _searchResults = [];
  bool _isSearching = false;
  LatLng? _searchedLocation;
  String? _searchedPlaceName;
  bool _showSearchResults = false;

  // Routes state
  List<JeepneyRoute> _routes = [];
  bool _isLoadingRoutes = true;
  String? _routesErrorMessage;
  final Set<int> _visibleRouteIds = {};

  // Route calculation state
  bool _isCalculatingRoute = false;
  List<SuggestedRoute> _calculatedRoutes = [];
  HybridRoutingResult? _hybridResult;

  SearchController({HybridRoutingConfig? config})
    : _hybridRouter = HybridTransitRouter(
        config:
            config ?? const HybridRoutingConfig(maxResults: 5, maxTransfers: 2),
      );

  // Getters
  LatLng? get currentLocation => _currentLocation;
  bool get isLoadingLocation => _isLoadingLocation;
  String get locationStatus => _locationStatus;
  String get currentAddress => _currentAddress;

  List<PlaceResult> get searchResults => _searchResults;
  bool get isSearching => _isSearching;
  LatLng? get searchedLocation => _searchedLocation;
  String? get searchedPlaceName => _searchedPlaceName;
  bool get showSearchResults => _showSearchResults;

  List<JeepneyRoute> get routes => _routes;
  bool get isLoadingRoutes => _isLoadingRoutes;
  String? get routesErrorMessage => _routesErrorMessage;
  Set<int> get visibleRouteIds => _visibleRouteIds;

  bool get isCalculatingRoute => _isCalculatingRoute;
  List<SuggestedRoute> get calculatedRoutes => _calculatedRoutes;
  HybridRoutingResult? get hybridResult => _hybridResult;

  /// Get sorted routes: visible routes first, then hidden
  List<JeepneyRoute> get sortedRoutes {
    final visibleRoutes = _routes
        .where((r) => _visibleRouteIds.contains(r.id))
        .toList();
    final hiddenRoutes = _routes
        .where((r) => !_visibleRouteIds.contains(r.id))
        .toList();

    visibleRoutes.sort((a, b) => a.name.compareTo(b.name));
    hiddenRoutes.sort((a, b) => a.name.compareTo(b.name));

    return [...visibleRoutes, ...hiddenRoutes];
  }

  /// Initialize - load location and routes
  Future<void> initialize() async {
    await Future.wait([getCurrentLocation(), fetchRoutes()]);
  }

  /// Get current location
  Future<void> getCurrentLocation() async {
    _isLoadingLocation = true;
    _locationStatus = 'Getting your location...';
    notifyListeners();

    try {
      final result = await _locationService.getCurrentLocation();

      if (result.isSuccess && result.location != null) {
        _currentLocation = result.location;
        _locationStatus = 'Location found';

        // Reverse geocode to get address
        final geocodeResult = await _locationService.reverseGeocode(
          result.location!,
        );
        if (geocodeResult.isSuccess) {
          _currentAddress = geocodeResult.formattedName;
        }
      } else {
        _locationStatus = result.error ?? 'Failed to get location';
      }
    } catch (e) {
      _locationStatus = 'Error: $e';
    } finally {
      _isLoadingLocation = false;
      notifyListeners();
    }
  }

  /// Fetch all routes from API
  Future<void> fetchRoutes() async {
    _isLoadingRoutes = true;
    _routesErrorMessage = null;
    notifyListeners();

    try {
      final routes = await _apiService.fetchAllRoutes();
      routes.sort((a, b) => a.name.compareTo(b.name));
      _routes = routes;
    } catch (e) {
      debugPrint('Routes API Error: $e');
      _routesErrorMessage = 'Failed to load routes';
    } finally {
      _isLoadingRoutes = false;
      notifyListeners();
    }
  }

  /// Search for places
  Future<void> searchPlaces(String query) async {
    if (query.isEmpty) {
      _showSearchResults = false;
      _searchResults = [];
      notifyListeners();
      return;
    }

    _isSearching = true;
    notifyListeners();

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?'
        'q=$query, Davao City, Philippines&'
        'format=json&'
        'limit=5&'
        'addressdetails=1',
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': 'LeJeepney App'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        _searchResults = data.map((place) {
          return PlaceResult(
            name: place['display_name'] ?? 'Unknown',
            lat: double.parse(place['lat']),
            lon: double.parse(place['lon']),
            type: place['type'] ?? '',
          );
        }).toList();
        _showSearchResults = true;
      }
    } catch (e) {
      debugPrint('Search error: $e');
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  /// Select a place from search results
  void selectPlace(PlaceResult place) {
    _currentAddress = place.name;
    _showSearchResults = false;
    _searchedLocation = place.location;
    _searchedPlaceName = place.name;
    _searchResults = [];
    notifyListeners();
  }

  /// Set searched location from map tap
  Future<void> setSearchedLocationFromTap(LatLng point) async {
    _searchedLocation = point;
    notifyListeners();

    // Reverse geocode to get place name
    final result = await _locationService.reverseGeocode(point);
    if (result.isSuccess) {
      _searchedPlaceName = result.formattedName;
      _currentAddress = result.formattedName;
      notifyListeners();
    }
  }

  /// Toggle route visibility
  void toggleRouteVisibility(int routeId) {
    if (_visibleRouteIds.contains(routeId)) {
      _visibleRouteIds.remove(routeId);
    } else {
      _visibleRouteIds.add(routeId);
    }
    notifyListeners();
  }

  /// Set visible routes
  void setVisibleRoutes(Set<int> routeIds) {
    _visibleRouteIds.clear();
    _visibleRouteIds.addAll(routeIds);
    notifyListeners();
  }

  /// Clear all visible routes
  void clearVisibleRoutes() {
    _visibleRouteIds.clear();
    notifyListeners();
  }

  /// Calculate route to destination
  Future<void> calculateRoute() async {
    if (_currentLocation == null || _searchedLocation == null) {
      return;
    }

    _isCalculatingRoute = true;
    notifyListeners();

    try {
      final result = await _hybridRouter.findRoutes(
        origin: _currentLocation!,
        destination: _searchedLocation!,
        jeepneyRoutes: _routes,
        osrmPath: null,
      );

      _calculatedRoutes = result.suggestedRoutes;
      _hybridResult = result;
    } catch (e) {
      debugPrint('Route calculation error: $e');
      _calculatedRoutes = [];
      _hybridResult = null;
    } finally {
      _isCalculatingRoute = false;
      notifyListeners();
    }
  }

  /// Clear search results
  void clearSearch() {
    _showSearchResults = false;
    _searchResults = [];
    _searchedLocation = null;
    _searchedPlaceName = null;
    notifyListeners();
  }

  /// Clear calculated routes
  void clearCalculatedRoutes() {
    _calculatedRoutes = [];
    _hybridResult = null;
    notifyListeners();
  }

  /// Get route by ID
  JeepneyRoute? getRouteById(int id) {
    try {
      return _routes.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Check if a route is visible
  bool isRouteVisible(int routeId) => _visibleRouteIds.contains(routeId);
}
