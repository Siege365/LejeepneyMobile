import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import '../../constants/app_colors.dart';
import '../../widgets/route_list_item.dart';
import '../../services/api_service.dart';
import '../../models/jeepney_route.dart';
import '../../utils/route_display_helpers.dart';
import '../../utils/transit_routing/transit_routing.dart';

class SearchScreen extends StatefulWidget {
  final int? autoSelectRouteId;
  final VoidCallback? onAutoSelectionComplete;

  const SearchScreen({
    super.key,
    this.autoSelectRouteId,
    this.onAutoSelectionComplete,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final MapController _mapController = MapController();
  final FocusNode _searchFocusNode = FocusNode();
  final ApiService _apiService = ApiService();

  LatLng? _currentLocation;
  bool _isLoadingLocation = true;
  String _locationStatus = 'Getting your location...';
  String _currentAddress = 'Davao City, Philippines';
  String _originalLocationAddress = 'Davao City, Philippines';
  bool _showRoutesList = false;
  bool _showSearchResults = false;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  LatLng? _searchedLocation;
  String? _searchedPlaceName;

  // API Routes data
  List<JeepneyRoute> _routes = [];
  bool _isLoadingRoutes = true;
  String? _routesErrorMessage;

  // Visible routes on map (route ID -> toggle state)
  final Set<int> _visibleRouteIds = {};

  // Track if we've already handled auto-selection to prevent repeated triggers
  bool _hasHandledAutoSelection = false;

  // Hybrid routing state
  final HybridTransitRouter _hybridRouter = HybridTransitRouter(
    config: const HybridRoutingConfig(maxResults: 5, maxTransfers: 2),
  );
  bool _isCalculatingRoute = false;
  List<SuggestedRoute> _calculatedRoutes = [];
  HybridRoutingResult? _hybridResult;

  // Sorted routes: visible routes first (alphabetically), then hidden routes (alphabetically)
  List<JeepneyRoute> get _sortedRoutes {
    final visibleRoutes = _routes
        .where((r) => _visibleRouteIds.contains(r.id))
        .toList();
    final hiddenRoutes = _routes
        .where((r) => !_visibleRouteIds.contains(r.id))
        .toList();

    // Sort each group alphabetically
    visibleRoutes.sort((a, b) => a.name.compareTo(b.name));
    hiddenRoutes.sort((a, b) => a.name.compareTo(b.name));

    // Combine: visible first, then hidden
    return [...visibleRoutes, ...hiddenRoutes];
  }

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _fetchRoutes();
    _searchController.addListener(_onSearchChanged);

    // Handle auto-selection after routes are loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleAutoSelection();
    });
  }

  void _handleAutoSelection() async {
    // Only handle auto-selection once and only if route ID was provided
    if (_hasHandledAutoSelection || widget.autoSelectRouteId == null) return;

    final routeId = widget.autoSelectRouteId!;

    // Mark as handled to prevent repeated triggers
    _hasHandledAutoSelection = true;

    // Wait for routes to load
    while (_isLoadingRoutes) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // Find and select the route
    final route = _routes.firstWhere(
      (r) => r.id == routeId,
      orElse: () => _routes.first,
    );

    if (mounted) {
      setState(() {
        _visibleRouteIds.add(route.id);
        _showRoutesList = true;
      });

      // Zoom to route if it has path
      if (route.path.isNotEmpty) {
        _zoomToRoute(route);
      }

      // Notify parent that auto-selection is complete so it can clear the ID
      widget.onAutoSelectionComplete?.call();
    }
  }

  void _zoomToRoute(JeepneyRoute route) {
    if (route.path.isEmpty) return;

    double minLat = route.path.first.latitude;
    double maxLat = route.path.first.latitude;
    double minLng = route.path.first.longitude;
    double maxLng = route.path.first.longitude;

    for (final point in route.path) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng)),
        padding: const EdgeInsets.all(60),
      ),
    );
  }

  Future<void> _fetchRoutes() async {
    setState(() {
      _isLoadingRoutes = true;
      _routesErrorMessage = null;
    });

    try {
      final routes = await _apiService.fetchAllRoutes();
      if (mounted) {
        // Sort routes alphabetically by name (A-Z)
        routes.sort((a, b) => a.name.compareTo(b.name));

        setState(() {
          _routes = routes;
          _isLoadingRoutes = false;
        });
      }
    } catch (e) {
      debugPrint('Routes API Error: $e');
      if (mounted) {
        setState(() {
          _isLoadingRoutes = false;
          _routesErrorMessage = 'Failed to load routes';
        });
      }
    }
  }

  void _onSearchChanged() {
    if (_searchController.text.isEmpty) {
      setState(() {
        _showSearchResults = false;
        _searchResults = [];
      });
    }
  }

  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
    });

    try {
      // Use Nominatim API (OpenStreetMap's geocoding service)
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?'
        'q=$query, Davao City, Philippines&'
        'format=json&'
        'limit=5&'
        'addressdetails=1',
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': 'Lejeepney App'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        setState(() {
          _searchResults = data.map((place) {
            return {
              'name': place['display_name'] ?? 'Unknown',
              'lat': double.parse(place['lat']),
              'lon': double.parse(place['lon']),
              'type': place['type'] ?? '',
            };
          }).toList();
          _showSearchResults = true;
          _isSearching = false;
        });
      }
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error searching: $e')));
      }
    }
  }

  void _selectPlace(Map<String, dynamic> place) {
    final location = LatLng(place['lat'], place['lon']);

    setState(() {
      _currentAddress = place['name'];
      _showSearchResults = false;
      _searchController.text = '';
      _searchedLocation = location;
      _searchedPlaceName = place['name'];
    });

    _mapController.move(location, 16.0);
    _searchFocusNode.unfocus();
  }

  void _showDirectionsModal() async {
    if (_searchedLocation == null) return;

    // Check if we have current location
    if (_currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Getting your location...'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Show loading modal first
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      isScrollControlled: true,
      builder: (context) => _buildRouteCalculationModal(),
    );

    // Calculate route
    await _calculateRoute();
  }

  Future<void> _calculateRoute() async {
    setState(() {
      _isCalculatingRoute = true;
    });

    try {
      // Use hybrid router to find routes
      final result = await _hybridRouter.findRoutes(
        origin: _currentLocation!,
        destination: _searchedLocation!,
        jeepneyRoutes: _routes,
        osrmPath: null, // Let it calculate without OSRM for now
      );

      setState(() {
        _calculatedRoutes = result.suggestedRoutes;
        _hybridResult = result;
        _isCalculatingRoute = false;
      });
    } catch (e) {
      setState(() {
        _isCalculatingRoute = false;
      });
      if (mounted) {
        Navigator.pop(context); // Close the modal
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error calculating route: $e')));
      }
    }
  }

  Widget _buildRouteCalculationModal() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Suggested Routes',
                      style: GoogleFonts.slackey(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkBlue,
                      ),
                    ),
                    const Spacer(),
                    if (!_isCalculatingRoute)
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          Navigator.pop(context);
                          setState(() {
                            _searchedLocation = null;
                            _searchedPlaceName = null;
                            _searchController.clear();
                            _currentAddress = _originalLocationAddress;
                            _visibleRouteIds.clear();
                          });
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                // From - To
                Row(
                  children: [
                    const Icon(Icons.my_location, color: Colors.blue, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _locationStatus,
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _searchedPlaceName ?? 'Destination',
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
              ],
            ),
          ),
          // Content
          Flexible(
            child: _isCalculatingRoute
                ? _buildLoadingState()
                : _calculatedRoutes.isEmpty
                ? _buildNoRoutesState()
                : _buildRoutesListState(),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Finding best routes...',
              style: TextStyle(fontSize: 15, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoRoutesState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.directions_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No routes found',
              style: GoogleFonts.slackey(
                fontSize: 18,
                color: AppColors.darkBlue,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try selecting a different location',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoutesListState() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      shrinkWrap: true,
      itemCount: _calculatedRoutes.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final route = _calculatedRoutes[index];
        return _buildRouteCard(route, index);
      },
    );
  }

  Widget _buildRouteCard(SuggestedRoute route, int index) {
    final rankColors = [
      Colors.amber[700]!, // Gold
      Colors.grey[600]!, // Silver
      Colors.brown[600]!, // Bronze
    ];
    final rankIcons = [Icons.looks_one, Icons.looks_two, Icons.looks_3];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // Close modal
          Navigator.pop(context);

          // Get all jeepney routes from this suggested route
          final jeepneyRoutes = route.segments
              .where((s) => s.route != null)
              .map((s) => s.route!)
              .toList();

          if (jeepneyRoutes.isEmpty) return;

          setState(() {
            // Toggle visibility of these routes
            final routeIds = jeepneyRoutes.map((r) => r.id).toSet();

            // Check if all routes are already visible
            final allVisible = routeIds.every(
              (id) => _visibleRouteIds.contains(id),
            );

            if (allVisible) {
              // Remove all these routes
              _visibleRouteIds.removeAll(routeIds);
            } else {
              // Add all these routes
              _visibleRouteIds.addAll(routeIds);
            }
          });

          // Fit map to show all the routes
          if (_visibleRouteIds.isNotEmpty) {
            _fitMapToMultipleRoutes(jeepneyRoutes);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Rank and route type
              Row(
                children: [
                  if (index < 3)
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: rankColors[index].withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        rankIcons[index],
                        size: 18,
                        color: rankColors[index],
                      ),
                    ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: route.transferCount == 0
                          ? Colors.green.withOpacity(0.1)
                          : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      route.transferCount == 0
                          ? 'Direct'
                          : '${route.transferCount} Transfer${route.transferCount > 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: route.transferCount == 0
                            ? Colors.green[700]
                            : Colors.orange[700],
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '\u20b1${route.totalFare.toStringAsFixed(2)}',
                    style: GoogleFonts.slackey(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkBlue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Route segments
              ...route.segments.asMap().entries.map((entry) {
                final segment = entry.value;
                final isLast = entry.key == route.segments.length - 1;

                if (segment.type == JourneySegmentType.walking) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.directions_walk,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Walk ${(segment.distanceKm * 1000).toStringAsFixed(0)}m',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  );
                } else if (segment.type == JourneySegmentType.jeepneyRide) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.darkBlue,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.directions_bus,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ride: ${segment.route?.routeNumber ?? 'Jeepney'}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.darkBlue,
                                ),
                              ),
                              if (segment.route?.name != null)
                                Text(
                                  segment.route!.name,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '\u20b1${segment.fare.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkBlue,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              }).toList(),
              const Divider(height: 20),
              // Summary
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSummaryItem(
                    Icons.access_time,
                    '~${route.estimatedTimeMinutes.toStringAsFixed(0)} min',
                  ),
                  _buildSummaryItem(
                    Icons.directions_walk,
                    '${(route.totalWalkingDistanceKm * 1000).toStringAsFixed(0)}m walk',
                  ),
                  _buildSummaryItem(
                    Icons.straighten,
                    '${route.totalDistanceKm.toStringAsFixed(1)} km',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 11, color: Colors.grey[700])),
      ],
    );
  }

  Future<void> _getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationStatus = 'Location services disabled';
          _isLoadingLocation = false;
        });
        return;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _locationStatus = 'Location permission denied';
            _isLoadingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationStatus = 'Location permissions permanently denied';
          _isLoadingLocation = false;
        });
        return;
      }

      // Get current position with timeout
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );

      if (mounted) {
        // Check if location is in Philippines (latitude 4-21°N, longitude 116-127°E)
        bool isInPhilippines =
            position.latitude >= 4 &&
            position.latitude <= 21 &&
            position.longitude >= 116 &&
            position.longitude <= 127;

        LatLng location;
        String address;

        if (isInPhilippines) {
          location = LatLng(position.latitude, position.longitude);
          address =
              '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
        } else {
          // Emulator default location, use Davao City instead
          location = LatLng(7.0731, 125.6128);
          address = 'Davao City, Philippines';
        }

        setState(() {
          _currentLocation = location;
          _locationStatus = isInPhilippines
              ? 'Your Location'
              : 'Davao City (Default)';
          _isLoadingLocation = false;
          _currentAddress = address;
          _originalLocationAddress = address;
        });

        // Move map to current location
        _mapController.move(_currentLocation!, 15.0);

        // Listen to location changes
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10, // Update every 10 meters
          ),
        ).listen((Position position) {
          if (mounted) {
            setState(() {
              _currentLocation = LatLng(position.latitude, position.longitude);
            });
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationStatus = 'Davao City (Default)';
          _isLoadingLocation = false;
          // Always use Davao City as default
          _currentLocation = LatLng(7.0731, 125.6128);
          _currentAddress = 'Davao City, Philippines';
          _originalLocationAddress = 'Davao City, Philippines';
        });

        // Move to Davao City
        _mapController.move(_currentLocation!, 15.0);
      }
    }
  }

  void _recenterToUserLocation() {
    if (_currentLocation != null) {
      _mapController.move(_currentLocation!, 15.0);
    }
  }

  void _fitMapToRoute(JeepneyRoute route) {
    if (route.path.isEmpty) return;

    double minLat = route.path[0].latitude;
    double maxLat = route.path[0].latitude;
    double minLng = route.path[0].longitude;
    double maxLng = route.path[0].longitude;

    for (var point in route.path) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    final bounds = LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng));

    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
    );
  }

  void _fitMapToMultipleRoutes(List<JeepneyRoute> routes) {
    if (routes.isEmpty) return;

    // Collect all points from all routes
    final allPoints = <LatLng>[];
    for (var route in routes) {
      allPoints.addAll(route.path);
    }

    if (allPoints.isEmpty) return;

    double minLat = allPoints[0].latitude;
    double maxLat = allPoints[0].latitude;
    double minLng = allPoints[0].longitude;
    double maxLng = allPoints[0].longitude;

    for (var point in allPoints) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    final bounds = LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng));

    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)),
    );
  }

  Color? _parseColor(String? colorString) {
    return parseHexColor(colorString);
  }

  List<Marker> _buildDirectionArrows(JeepneyRoute route) {
    List<Marker> arrows = [];

    if (route.path.length < 2) return arrows;

    // Calculate arrow positions every 500 meters
    List<ArrowPoint> arrowPoints = calculateArrowPoints(route.path, 500.0);

    Color routeColor = parseHexColor(route.color) ?? Colors.blue;
    Color arrowColor = getContrastColor(routeColor);

    for (var arrowPoint in arrowPoints) {
      arrows.add(
        Marker(
          point: arrowPoint.position,
          width: 28,
          height: 28,
          child: Transform.rotate(
            angle: arrowPoint.bearing * pi / 180,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.9),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Icon(
                Icons.arrow_forward,
                color: arrowColor,
                size: 18,
                shadows: [
                  Shadow(color: Colors.white.withOpacity(0.8), blurRadius: 2),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return arrows;
  }

  List<Marker> _buildRouteMarkers(JeepneyRoute route) {
    List<Marker> markers = [];

    if (route.path.isEmpty) return markers;

    // Start Point Marker (Green with Play Icon + Pulsing Animation)
    markers.add(
      Marker(
        point: route.path.first,
        width: 50,
        height: 70,
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.4),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'START',
                style: GoogleFonts.slackey(
                  fontSize: 8,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    // End Point Marker (Red with Stop Icon + Pulsing Animation)
    markers.add(
      Marker(
        point: route.path.last,
        width: 50,
        height: 70,
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.4),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.stop, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'END',
                style: GoogleFonts.slackey(
                  fontSize: 8,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return markers;
  }

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
          // OpenStreetMap
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: LatLng(7.0731, 125.6128), // Davao City default
                initialZoom: 14.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.final_project_cce106',
                ),
                if (_currentLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _currentLocation!,
                        width: 50,
                        height: 50,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Outer pulsing circle
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                            ),
                            // Inner dot
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                // Searched Location Pin
                if (_searchedLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _searchedLocation!,
                        width: 60,
                        height: 60,
                        alignment: Alignment.topCenter,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.darkBlue,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _searchedPlaceName ?? '',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(
                              Icons.location_on,
                              color: Colors.red,
                              size: 40,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                // Route Polylines
                if (_visibleRouteIds.isNotEmpty)
                  PolylineLayer(
                    polylines: _routes
                        .where(
                          (route) =>
                              _visibleRouteIds.contains(route.id) &&
                              route.path.isNotEmpty,
                        )
                        .map((route) {
                          Color routeColor =
                              parseHexColor(route.color) ?? Colors.blue;
                          return Polyline(
                            points: route.path,
                            color: routeColor,
                            strokeWidth: 7.0,
                            borderStrokeWidth: 2.0,
                            borderColor: Colors.black.withOpacity(0.3),
                          );
                        })
                        .toList(),
                  ),
                // Direction Arrows
                if (_visibleRouteIds.isNotEmpty)
                  MarkerLayer(
                    markers: _routes
                        .where(
                          (route) =>
                              _visibleRouteIds.contains(route.id) &&
                              route.path.isNotEmpty,
                        )
                        .expand((route) => _buildDirectionArrows(route))
                        .toList(),
                  ),
                // Route Start/End Markers
                if (_visibleRouteIds.isNotEmpty)
                  MarkerLayer(
                    markers: _routes
                        .where(
                          (route) =>
                              _visibleRouteIds.contains(route.id) &&
                              route.path.isNotEmpty,
                        )
                        .expand((route) => _buildRouteMarkers(route))
                        .toList(),
                  ),
              ],
            ),
          ),

          // Content
          SafeArea(
            child: Column(
              children: [
                // Search Bar
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
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
                              suffixIcon: _isSearching
                                  ? const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  : _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        _searchController.clear();
                                      },
                                    )
                                  : const Icon(Icons.mic),
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
                              if (value.isNotEmpty) {
                                _searchPlaces(value);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Search Results
                if (_showSearchResults && _searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final place = _searchResults[index];
                        return ListTile(
                          leading: const Icon(
                            Icons.place,
                            color: AppColors.darkBlue,
                          ),
                          title: Text(
                            place['name'],
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14),
                          ),
                          subtitle: Text(
                            place['type'],
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          onTap: () => _selectPlace(place),
                        );
                      },
                    ),
                  ),

                // Location Status
                if (_isLoadingLocation || _currentLocation != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
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
                            const Icon(
                              Icons.my_location,
                              color: Colors.blue,
                              size: 16,
                            ),
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
                  ),

                // Spacer
                Expanded(child: Container()),
              ],
            ),
          ),

          // Get Directions Button (appears when location is searched)
          if (_searchedLocation != null)
            Positioned(
              right: 16,
              bottom: _showRoutesList ? 350 : 170,
              child: FloatingActionButton(
                onPressed: _showDirectionsModal,
                backgroundColor: AppColors.darkBlue,
                child: const Icon(Icons.directions, color: AppColors.white),
              ),
            ),

          // Re-center to Location Button (Floating)
          if (_currentLocation != null)
            Positioned(
              right: 16,
              bottom: _showRoutesList ? 280 : 100,
              child: FloatingActionButton(
                onPressed: _recenterToUserLocation,
                backgroundColor: AppColors.white,
                child: const Icon(Icons.my_location, color: AppColors.darkBlue),
              ),
            ),

          // Routes Toggle Button at Bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Show/Hide Routes Button
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _showRoutesList = !_showRoutesList;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.darkBlue,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
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
                  ),
                  const SizedBox(height: 8),

                  // Routes List Card (Animated)
                  if (_showRoutesList)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(20),
                      constraints: const BoxConstraints(maxHeight: 300),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, -4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'List of Routes',
                                style: GoogleFonts.slackey(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              if (_isLoadingRoutes)
                                const Padding(
                                  padding: EdgeInsets.only(left: 12),
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Route Items - Dynamic from API
                          if (_isLoadingRoutes)
                            const Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(),
                            )
                          else if (_routesErrorMessage != null)
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.wifi_off,
                                    color: AppColors.warning,
                                    size: 32,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _routesErrorMessage!,
                                    style: TextStyle(color: AppColors.warning),
                                  ),
                                  const SizedBox(height: 8),
                                  TextButton.icon(
                                    onPressed: _fetchRoutes,
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Retry'),
                                  ),
                                ],
                              ),
                            )
                          else if (_routes.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'No routes available',
                                style: TextStyle(color: AppColors.gray),
                              ),
                            )
                          else
                            Flexible(
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: _sortedRoutes.length,
                                itemBuilder: (context, index) {
                                  final route = _sortedRoutes[index];
                                  final isVisible = _visibleRouteIds.contains(
                                    route.id,
                                  );
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: RouteListItem(
                                      routeName: route.displayName,
                                      isAvailable: route.isAvailable,
                                      isRouteVisible: isVisible,
                                      onTap: () {
                                        debugPrint(
                                          'Route ${route.displayName} tapped, ID: ${route.id}',
                                        );
                                        setState(() {
                                          if (isVisible) {
                                            debugPrint(
                                              'Hiding route ${route.id}',
                                            );
                                            _visibleRouteIds.remove(route.id);
                                          } else {
                                            debugPrint(
                                              'Showing route ${route.id}, path length: ${route.path.length}',
                                            );
                                            _visibleRouteIds.add(route.id);
                                            // Fit map to show route if it has path
                                            if (route.path.isNotEmpty) {
                                              _fitMapToRoute(route);
                                            }
                                          }
                                          debugPrint(
                                            'Visible routes: $_visibleRouteIds',
                                          );
                                        });
                                      },
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20), // Space for bottom nav
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
