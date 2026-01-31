// Search Screen - Map-based search with route display
// Refactored to follow SOLID principles:
// - Uses LocationService for GPS operations
// - Uses extracted widgets for UI components
// - Uses MapConstants for configuration values

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../constants/app_colors.dart';
import '../../constants/map_constants.dart';
import '../../widgets/map/map_markers.dart';
import '../../widgets/route/route_display_widgets.dart';
import '../../widgets/route/suggested_routes_modal.dart';
import '../../widgets/route/routes_list_panel.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';
import '../../models/jeepney_route.dart';
import '../../utils/transit_routing/transit_routing.dart';

class SearchScreen extends StatefulWidget {
  final int? autoSelectRouteId;
  final List<int>? autoSelectRouteIds;
  final double? landmarkLatitude;
  final double? landmarkLongitude;
  final String? landmarkName;
  final VoidCallback? onAutoSelectionComplete;

  const SearchScreen({
    super.key,
    this.autoSelectRouteId,
    this.autoSelectRouteIds,
    this.landmarkLatitude,
    this.landmarkLongitude,
    this.landmarkName,
    this.onAutoSelectionComplete,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  // Controllers
  final TextEditingController _searchController = TextEditingController();
  final MapController _mapController = MapController();
  final FocusNode _searchFocusNode = FocusNode();

  // Services
  final ApiService _apiService = ApiService();
  final LocationService _locationService = LocationService();
  final HybridTransitRouter _hybridRouter = HybridTransitRouter(
    config: const HybridRoutingConfig(maxResults: 5, maxTransfers: 3),
  );

  // Location state
  LatLng? _currentLocation;
  bool _isLoadingLocation = true;
  String _locationStatus = 'Getting your location...';
  String _currentAddress = MapConstants.defaultLocationName;
  String _originalLocationAddress = MapConstants.defaultLocationName;

  // Search state
  bool _showSearchResults = false;
  List<PlaceSearchResult> _searchResults = [];
  bool _isSearching = false;
  LatLng? _searchedLocation;
  String? _searchedPlaceName;

  // Routes state
  List<JeepneyRoute> _routes = [];
  bool _isLoadingRoutes = true;
  String? _routesErrorMessage;
  final Set<int> _visibleRouteIds = {};
  bool _showRoutesList = false;
  bool _hasHandledAutoSelection = false;

  // Routing state
  bool _isCalculatingRoute = false;
  List<SuggestedRoute> _calculatedRoutes = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initializeScreen();
    });
  }

  Future<void> _initializeScreen() async {
    await _getCurrentLocation();
    await _fetchRoutes();
    _handleAutoSelection();
    _handleLandmarkNavigation();
  }

  // ========== LOCATION METHODS ==========

  Future<void> _getCurrentLocation() async {
    final result = await _locationService.getCurrentPosition();

    if (!mounted) return;

    if (result.isSuccess && result.location != null) {
      // Validate coordinates
      final pos = result.location!;
      final isValid =
          pos.latitude.abs() > 0.1 &&
          pos.longitude.abs() > 0.1 &&
          pos.latitude.abs() < 90 &&
          pos.longitude.abs() < 180;

      if (isValid) {
        final address =
            '${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}';

        setState(() {
          _currentLocation = pos;
          _locationStatus = 'Your Location';
          _isLoadingLocation = false;
          _currentAddress = address;
          _originalLocationAddress = address;
        });

        _mapController.move(pos, MapConstants.userLocationZoom);
        _startLocationUpdates();
        return;
      }
    }

    // Fall back to default
    _setDefaultLocation(result.error);
  }

  void _setDefaultLocation([String? reason]) {
    if (!mounted) return;

    debugPrint('Using default location: ${reason ?? "No reason"}');

    setState(() {
      _currentLocation = MapConstants.defaultLocation;
      _locationStatus = 'Davao City (Default)';
      _isLoadingLocation = false;
      _currentAddress = MapConstants.defaultLocationWithSuffix;
      _originalLocationAddress = MapConstants.defaultLocationWithSuffix;
    });

    _mapController.move(
      MapConstants.defaultLocation,
      MapConstants.userLocationZoom,
    );
  }

  void _startLocationUpdates() {
    _locationService.getPositionStream().listen((position) {
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
        });
      }
    });
  }

  void _recenterToUserLocation() {
    if (_currentLocation != null) {
      _mapController.move(_currentLocation!, MapConstants.userLocationZoom);
    }
  }

  // ========== ROUTES METHODS ==========

  Future<void> _fetchRoutes() async {
    setState(() {
      _isLoadingRoutes = true;
      _routesErrorMessage = null;
    });

    try {
      final routes = await _apiService.fetchAllRoutes();
      if (mounted) {
        routes.sort((a, b) => a.name.compareTo(b.name));
        setState(() {
          _routes = routes;
          // Keep loading state while building graph
        });

        // Pre-initialize the routing graph in the background
        // This makes subsequent route calculations faster
        debugPrint('[SearchScreen] Pre-building transit graph...');
        await _hybridRouter.preInitialize(routes: routes);
        debugPrint('[SearchScreen] Graph pre-build complete');

        if (mounted) {
          setState(() {
            _isLoadingRoutes = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Routes API Error: $e');
      if (mounted) {
        final errorMsg = e.toString().contains('ApiException')
            ? e.toString().replaceAll('ApiException: ', '')
            : 'Failed to load routes. Please check your internet connection.';

        setState(() {
          _isLoadingRoutes = false;
          _routesErrorMessage = errorMsg;
        });

        // Show snackbar with error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _fetchRoutes,
            ),
          ),
        );
      }
    }
  }

  void _handleAutoSelection() async {
    if (_hasHandledAutoSelection) return;

    if (widget.autoSelectRouteId == null &&
        (widget.autoSelectRouteIds == null ||
            widget.autoSelectRouteIds!.isEmpty)) {
      return;
    }

    _hasHandledAutoSelection = true;

    while (_isLoadingRoutes) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (!mounted) return;

    setState(() {
      if (widget.autoSelectRouteIds != null &&
          widget.autoSelectRouteIds!.isNotEmpty) {
        _visibleRouteIds.addAll(widget.autoSelectRouteIds!);
        _showRoutesList = true;

        final selectedRoutes = _routes
            .where((r) => widget.autoSelectRouteIds!.contains(r.id))
            .toList();
        if (selectedRoutes.isNotEmpty) {
          _fitMapToRoutes(selectedRoutes);
        }
      } else if (widget.autoSelectRouteId != null) {
        final route = _routes.firstWhere(
          (r) => r.id == widget.autoSelectRouteId,
          orElse: () => _routes.first,
        );
        _visibleRouteIds.add(route.id);
        _showRoutesList = true;

        if (route.path.isNotEmpty) {
          _zoomToRoute(route);
        }
      }
    });

    widget.onAutoSelectionComplete?.call();
  }

  void _handleLandmarkNavigation() async {
    if (widget.landmarkLatitude == null || widget.landmarkLongitude == null) {
      return;
    }

    while (_isLoadingLocation) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (_currentLocation == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to get your location. Please enable GPS.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      widget.onAutoSelectionComplete?.call();
      return;
    }

    final landmarkLocation = LatLng(
      widget.landmarkLatitude!,
      widget.landmarkLongitude!,
    );
    final landmarkName = widget.landmarkName ?? 'Selected Location';

    if (mounted) {
      setState(() {
        _searchedLocation = landmarkLocation;
        _searchedPlaceName = landmarkName;
        _searchController.text = landmarkName;
        _currentAddress = landmarkName;
      });

      _mapController.move(landmarkLocation, MapConstants.searchZoom);

      Future.delayed(const Duration(milliseconds: 500), () {
        widget.onAutoSelectionComplete?.call();
      });
    }
  }

  void _onRouteToggled(JeepneyRoute route, bool isNowVisible) {
    setState(() {
      if (isNowVisible) {
        _visibleRouteIds.add(route.id);
        if (route.path.isNotEmpty) {
          _zoomToRoute(route);
        }
      } else {
        _visibleRouteIds.remove(route.id);
      }
    });
  }

  void _zoomToRoute(JeepneyRoute route) {
    if (route.path.isEmpty) return;

    final bounds = _calculateBounds(route.path);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(MapConstants.routePadding),
      ),
    );
  }

  void _fitMapToRoutes(List<JeepneyRoute> routes) {
    final allPoints = routes.expand((r) => r.path).toList();
    if (allPoints.isEmpty) return;

    final bounds = _calculateBounds(allPoints);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(MapConstants.routePadding),
      ),
    );
  }

  LatLngBounds _calculateBounds(List<LatLng> points) {
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    return LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng));
  }

  // ========== SEARCH METHODS ==========

  void _onSearchChanged() {
    if (_searchController.text.isEmpty) {
      Future.microtask(() {
        if (mounted) {
          setState(() {
            _showSearchResults = false;
            _searchResults = [];
          });
        }
      });
    }
  }

  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty) return;

    setState(() => _isSearching = true);

    try {
      final results = await _locationService.searchPlaces(query);

      if (mounted) {
        setState(() {
          _searchResults = results;
          _showSearchResults = true;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error searching: $e')));
      }
    }
  }

  void _selectPlace(PlaceSearchResult place) {
    setState(() {
      _currentAddress = place.displayName;
      _showSearchResults = false;
      _searchController.text = '';
      _searchedLocation = place.latLng;
      _searchedPlaceName = place.displayName;
    });

    _mapController.move(place.latLng, MapConstants.searchZoom);
    _searchFocusNode.unfocus();
  }

  Future<void> _handleMapLongPress(LatLng point) async {
    try {
      final result = await _locationService.reverseGeocode(point);

      if (mounted && result.isSuccess) {
        setState(() {
          _searchedLocation = point;
          _searchedPlaceName = result.displayName;
          _currentAddress = result.displayName ?? 'Selected Location';
        });
      }
    } catch (e) {
      debugPrint('Error fetching place info: $e');
    }
  }

  // ========== DIRECTIONS METHODS ==========

  void _showDirectionsModal() async {
    if (!mounted || _searchedLocation == null) return;

    if (_currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Getting your location...'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      isScrollControlled: true,
      builder: (context) => SuggestedRoutesModal(
        routes: _calculatedRoutes,
        isCalculating: _isCalculatingRoute,
        originName: _locationStatus,
        destinationName: _searchedPlaceName ?? 'Destination',
        onClose: _clearSearch,
        onRouteSelected: _onSuggestedRouteSelected,
      ),
    );

    await _calculateRoute();
  }

  Future<void> _calculateRoute() async {
    if (!mounted) return;

    // Wait for routes to load and graph to be pre-initialized
    if (_isLoadingRoutes) {
      debugPrint(
        '[SearchScreen] Waiting for routes to load and graph to initialize...',
      );
      setState(() => _isCalculatingRoute = true);

      // Poll until routes are loaded
      while (_isLoadingRoutes && mounted) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      if (!mounted) {
        setState(() => _isCalculatingRoute = false);
        return;
      }

      debugPrint('[SearchScreen] Routes loaded, proceeding with calculation');
    }

    setState(() => _isCalculatingRoute = true);

    try {
      final result = await _hybridRouter
          .findRoutes(
            origin: _currentLocation!,
            destination: _searchedLocation!,
            jeepneyRoutes: _routes,
            osrmPath: null,
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              debugPrint('[SearchScreen] Route calculation timed out');
              throw TimeoutException('Route calculation took too long');
            },
          );

      if (mounted) {
        setState(() {
          _calculatedRoutes = result.suggestedRoutes;
          _isCalculatingRoute = false;
        });

        // Show feedback if no routes found
        if (result.suggestedRoutes.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'No jeepney routes found for this destination. '
                'Try a location closer to a main road.',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } on TimeoutException {
      if (!mounted) return;

      setState(() => _isCalculatingRoute = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Route calculation is taking too long. Please try again.',
          ),
          backgroundColor: Colors.orange,
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: _showDirectionsModal,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _isCalculatingRoute = false);

      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Network error. Please check your connection.'),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: _showDirectionsModal,
          ),
        ),
      );
    }
  }

  void _onSuggestedRouteSelected(SuggestedRoute route) {
    Navigator.pop(context);

    final jeepneyRoutes = route.segments
        .where((s) => s.route != null)
        .map((s) => s.route!)
        .toList();

    if (jeepneyRoutes.isEmpty) return;

    setState(() {
      final routeIds = jeepneyRoutes.map((r) => r.id).toSet();
      final allVisible = routeIds.every((id) => _visibleRouteIds.contains(id));

      if (allVisible) {
        _visibleRouteIds.removeAll(routeIds);
      } else {
        _visibleRouteIds.addAll(routeIds);
      }
    });

    if (_visibleRouteIds.isNotEmpty) {
      _fitMapToRoutes(jeepneyRoutes);
    }
  }

  void _clearSearch() {
    Navigator.pop(context);
    if (mounted) {
      setState(() {
        _searchedLocation = null;
        _searchedPlaceName = null;
        _searchController.clear();
        _currentAddress = _originalLocationAddress;
        _visibleRouteIds.clear();
      });
    }
  }

  // ========== SORTED ROUTES ==========

  List<JeepneyRoute> get _sortedRoutes {
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

  List<JeepneyRoute> get _visibleRoutes => _routes
      .where((r) => _visibleRouteIds.contains(r.id) && r.path.isNotEmpty)
      .toList();

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Stack(
        children: [
          _buildMap(),
          _buildSearchOverlay(),
          if (_searchedLocation != null) _buildDirectionsButton(),
          if (_currentLocation != null) _buildRecenterButton(),
          _buildRoutesToggle(),
        ],
      ),
    );
  }

  // ========== MAP WIDGET ==========

  Widget _buildMap() {
    return Positioned.fill(
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: MapConstants.defaultLocation,
          initialZoom: MapConstants.defaultZoom,
          onLongPress: (tapPosition, point) => _handleMapLongPress(point),
        ),
        children: [
          TileLayer(
            urlTemplate: MapConstants.osmTileUrl,
            userAgentPackageName: MapConstants.appUserAgent,
            tileProvider: NetworkTileProvider(),
            errorTileCallback: (tile, error, stackTrace) {
              debugPrint('Tile loading error (${tile.coordinates}): $error');
            },
          ),
          // Current location marker
          if (_currentLocation != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: _currentLocation!,
                  width: 50,
                  height: 50,
                  child: const CurrentLocationMarker(),
                ),
              ],
            ),
          // Searched location marker
          if (_searchedLocation != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: _searchedLocation!,
                  width: 60,
                  height: 60,
                  alignment: Alignment.topCenter,
                  child: SearchedLocationMarker(
                    label: _searchedPlaceName?.split(',').first,
                  ),
                ),
              ],
            ),
          // Route polylines
          if (_visibleRouteIds.isNotEmpty)
            PolylineLayer(
              polylines: RoutePolylineBuilder.buildMultiple(_visibleRoutes),
            ),
          // Direction arrows
          if (_visibleRouteIds.isNotEmpty)
            MarkerLayer(
              markers: _visibleRoutes
                  .expand((route) => RouteDirectionArrows.build(route))
                  .toList(),
            ),
          // Route start/end markers
          if (_visibleRouteIds.isNotEmpty)
            MarkerLayer(
              markers: _visibleRoutes
                  .expand((route) => RouteEndpointMarkers.build(route))
                  .toList(),
            ),
        ],
      ),
    );
  }

  // ========== SEARCH OVERLAY ==========

  Widget _buildSearchOverlay() {
    return SafeArea(
      child: Column(
        children: [
          _buildSearchBar(),
          if (_showSearchResults && _searchResults.isNotEmpty)
            _buildSearchResults(),
          if (_isLoadingLocation || _currentLocation != null)
            _buildLocationStatus(),
          const Expanded(child: SizedBox.shrink()),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          decoration: InputDecoration(
            hintText: _currentAddress,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _buildSearchSuffix(),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: AppColors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 15,
            ),
          ),
          onSubmitted: (value) {
            if (value.isNotEmpty) _searchPlaces(value);
          },
        ),
      ),
    );
  }

  Widget _buildSearchSuffix() {
    if (_isSearching) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_searchController.text.isNotEmpty) {
      return IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () => _searchController.clear(),
      );
    }
    return const Icon(Icons.mic);
  }

  Widget _buildSearchResults() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      constraints: const BoxConstraints(maxHeight: 300),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: _searchResults.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final place = _searchResults[index];
          return ListTile(
            leading: const Icon(Icons.place, color: AppColors.darkBlue),
            title: Text(
              place.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14),
            ),
            subtitle: Text(
              place.type ?? '',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            onTap: () => _selectPlace(place),
          );
        },
      ),
    );
  }

  Widget _buildLocationStatus() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isLoadingLocation)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const Icon(Icons.my_location, color: Colors.blue, size: 16),
            const SizedBox(width: 8),
            Text(
              _locationStatus,
              style: GoogleFonts.slackey(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.darkBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========== FLOATING BUTTONS ==========

  Widget _buildDirectionsButton() {
    return Positioned(
      right: 16,
      bottom: _showRoutesList ? 350 : 170,
      child: FloatingActionButton(
        onPressed: _showDirectionsModal,
        backgroundColor: AppColors.darkBlue,
        child: const Icon(Icons.directions, color: AppColors.white),
      ),
    );
  }

  Widget _buildRecenterButton() {
    return Positioned(
      right: 16,
      bottom: _showRoutesList ? 280 : 100,
      child: FloatingActionButton(
        onPressed: _recenterToUserLocation,
        backgroundColor: AppColors.white,
        child: const Icon(Icons.my_location, color: Colors.blue),
      ),
    );
  }

  // ========== ROUTES TOGGLE ==========

  Widget _buildRoutesToggle() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildRoutesToggleButton(),
            const SizedBox(height: 8),
            if (_showRoutesList)
              RoutesListPanel(
                routes: _sortedRoutes,
                visibleRouteIds: _visibleRouteIds,
                isLoading: _isLoadingRoutes,
                errorMessage: _routesErrorMessage,
                onRetry: _fetchRoutes,
                onRouteToggled: _onRouteToggled,
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildRoutesToggleButton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ElevatedButton.icon(
        onPressed: () => setState(() => _showRoutesList = !_showRoutesList),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.darkBlue,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
        ),
        icon: Icon(
          _showRoutesList ? Icons.expand_more : Icons.route,
          color: AppColors.white,
        ),
        label: Text(
          _showRoutesList ? 'Hide Routes' : 'Show Routes',
          style: const TextStyle(
            color: AppColors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
