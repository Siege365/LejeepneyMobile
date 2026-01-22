import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../constants/app_colors.dart';
import '../../widgets/route_list_item.dart';
import '../../services/api_service.dart';
import '../../models/jeepney_route.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

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

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _fetchRoutes();
    _searchController.addListener(_onSearchChanged);
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

  Color? _parseColor(String? colorString) {
    if (colorString == null || colorString.isEmpty) return null;
    try {
      final hexColor = colorString.replaceAll('#', '');
      return Color(int.parse('FF$hexColor', radix: 16));
    } catch (e) {
      return null;
    }
  }

  List<Marker> _buildRouteMarkers(JeepneyRoute route) {
    List<Marker> markers = [];

    if (route.path.isEmpty) return markers;

    // Start Point Marker (Green with Play Icon)
    markers.add(
      Marker(
        point: route.path.first,
        width: 40,
        height: 40,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(Icons.play_arrow, color: Colors.white, size: 20),
        ),
      ),
    );

    // End Point Marker (Red with Stop Icon)
    markers.add(
      Marker(
        point: route.path.last,
        width: 40,
        height: 40,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(Icons.stop, color: Colors.white, size: 20),
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
                          return Polyline(
                            points: route.path,
                            color: _parseColor(route.color) ?? Colors.blue,
                            strokeWidth: 4.0,
                            borderStrokeWidth: 2.0,
                            borderColor: Colors.white,
                          );
                        })
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

          // Re-center to Location Button (Floating)
          if (_currentLocation != null)
            Positioned(
              right: 16,
              bottom: _showRoutesList ? 280 : 100,
              child: FloatingActionButton(
                onPressed: _recenterToUserLocation,
                backgroundColor: AppColors.white,
                child: const Icon(Icons.my_location, color: Colors.blue),
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
                                itemCount: _routes.length,
                                itemBuilder: (context, index) {
                                  final route = _routes[index];
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
