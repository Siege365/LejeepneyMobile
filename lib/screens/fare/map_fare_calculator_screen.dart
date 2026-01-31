import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../../constants/app_colors.dart';
import '../../constants/map_constants.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';
import '../../services/route_calculation_service.dart';
import '../../utils/route_matcher.dart'; // Still needed for RouteMatchResult type
import '../../utils/multi_transfer_matcher.dart';
import '../../utils/transit_routing/transit_routing.dart';

class MapFareCalculatorScreen extends StatefulWidget {
  final LatLng? initialPointA;
  final LatLng? initialPointB;
  final String? initialPointAName;
  final String? initialPointBName;
  final bool swapPoints; // Flag to swap points A and B

  const MapFareCalculatorScreen({
    super.key,
    this.initialPointA,
    this.initialPointB,
    this.initialPointAName,
    this.initialPointBName,
    this.swapPoints = false,
  });

  @override
  State<MapFareCalculatorScreen> createState() =>
      _MapFareCalculatorScreenState();
}

class _MapFareCalculatorScreenState extends State<MapFareCalculatorScreen> {
  final MapController _mapController = MapController();

  LatLng? _pointA;
  LatLng? _pointB;
  String? _areaA;
  String? _areaB;
  double? _distance;
  double? _fare;
  bool _isSelectingPointA = true;
  bool _isLoadingArea = false;
  bool _isLoadingRoute = false;
  bool _isLoadingLocation = false;
  List<LatLng> _routePath = [];

  // User location state
  LatLng? _userLocation;
  // ignore: unused_field - Reserved for permission-based UI logic
  bool _hasLocationPermission = false;

  // Route matching state
  bool _isMatchingRoutes = false;
  List<RouteMatchResult> _matchedRoutes = [];
  List<MultiTransferRoute> _multiTransferRoutes = [];
  List<SuggestedRoute> _suggestedRoutes = []; // New: hybrid routing results
  HybridRoutingResult? _hybridResult; // New: full hybrid result
  final LocationService _locationService = LocationService();
  final RouteCalculationService _routeCalculationService =
      RouteCalculationService(apiService: ApiService());

  @override
  void initState() {
    super.initState();
    _initLocationService();

    // Check if we should swap points
    if (widget.swapPoints &&
        widget.initialPointA != null &&
        widget.initialPointB != null) {
      // Swap: A becomes B, B becomes A
      _pointA = widget.initialPointB;
      _areaA = widget.initialPointBName ?? 'Selected Location';
      _pointB = widget.initialPointA;
      _areaB = widget.initialPointAName ?? 'Selected Location';
      _isSelectingPointA = false;

      // Automatically calculate route after swap
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _findMatchingJeepneyRoutes();
        if (_pointA != null) {
          _mapController.move(_pointA!, MapConstants.defaultZoom);
        }
      });
    } else if (widget.initialPointA != null) {
      // Normal initialization without swap
      _pointA = widget.initialPointA;
      _areaA = widget.initialPointAName ?? 'Selected Location';
      _isSelectingPointA = false;

      // If we also have point B, calculate route immediately
      if (widget.initialPointB != null) {
        _pointB = widget.initialPointB;
        _areaB = widget.initialPointBName ?? 'Selected Location';

        // Schedule route calculation after build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _findMatchingJeepneyRoutes();
        });
      }

      // Center map on point A
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pointA != null) {
          _mapController.move(_pointA!, MapConstants.defaultZoom);
        }
      });
    }
  }

  /// Initialize location service and get user's current position
  Future<void> _initLocationService() async {
    setState(() => _isLoadingLocation = true);

    try {
      final result = await _locationService.getCurrentPosition();

      if (result.isSuccess && result.location != null) {
        _hasLocationPermission = true;

        setState(() {
          _userLocation = result.location;
          _isLoadingLocation = false;
        });

        debugPrint('User location: $_userLocation');
      } else {
        debugPrint('Location error: ${result.error}');
        setState(() => _isLoadingLocation = false);
      }
    } catch (e) {
      debugPrint('Failed to get location: $e');
      setState(() => _isLoadingLocation = false);
    }
  }

  /// Use current location as Point A
  Future<void> _useCurrentLocationAsPointA() async {
    if (_userLocation == null) {
      // Try to get location again
      await _initLocationService();
      if (_userLocation == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to get your current location'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
    }

    // Set Point A to user location
    _onMapTapped(_userLocation!);

    // Center map on user location
    _mapController.move(_userLocation!, 15.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Map Fare Calculator',
          style: GoogleFonts.slackey(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      backgroundColor: AppColors.primary,
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: MapConstants.defaultLocation,
              initialZoom: MapConstants.defaultZoom,
              onTap: (tapPosition, point) => _onMapTapped(point),
            ),
            children: [
              TileLayer(
                urlTemplate: MapConstants.osmTileUrl,
                userAgentPackageName: MapConstants.appUserAgent,
              ),
              // Route Path - drawn along roads
              if (_routePath.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePath,
                      color: AppColors.darkBlue,
                      strokeWidth: 5.0,
                      borderColor: Colors.white,
                      borderStrokeWidth: 2.0,
                    ),
                  ],
                ),
              // Markers
              MarkerLayer(
                markers: [
                  if (_pointA != null)
                    Marker(
                      point: _pointA!,
                      width: 150,
                      height: 90,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            constraints: const BoxConstraints(maxWidth: 140),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade600,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              _areaA ?? 'Loading...',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(
                            Icons.location_on,
                            color: Colors.green,
                            size: 40,
                          ),
                        ],
                      ),
                    ),
                  if (_pointB != null)
                    Marker(
                      point: _pointB!,
                      width: 150,
                      height: 90,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            constraints: const BoxConstraints(maxWidth: 140),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade600,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              _areaB ?? 'Loading...',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
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
                  // User location marker (blue dot)
                  if (_userLocation != null && _pointA == null)
                    Marker(
                      point: _userLocation!,
                      width: 30,
                      height: 30,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withValues(alpha: 0.4),
                                  blurRadius: 4,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Loading Route Indicator
          if (_isLoadingRoute)
            Positioned(
              top: 130,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 20,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.darkBlue,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Creating route...',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Instructions Card
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
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
              child: Column(
                children: [
                  _buildPointRow(
                    label: 'A',
                    isActive: _isSelectingPointA,
                    color: Colors.green,
                    areaName: _areaA,
                    placeholder: 'Tap map to set starting point',
                    isLoading: _isLoadingArea && _isSelectingPointA,
                  ),
                  // Use My Location button
                  if (_isSelectingPointA && _pointA == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isLoadingLocation
                              ? null
                              : _useCurrentLocationAsPointA,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.blue,
                            side: const BorderSide(color: Colors.blue),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          icon: _isLoadingLocation
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.blue,
                                  ),
                                )
                              : const Icon(Icons.my_location, size: 18),
                          label: Text(
                            _isLoadingLocation
                                ? 'Getting location...'
                                : 'Use My Current Location',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  _buildPointRow(
                    label: 'B',
                    isActive: !_isSelectingPointA,
                    color: Colors.red,
                    areaName: _areaB,
                    placeholder: 'Tap map to set destination',
                    isLoading: _isLoadingArea && !_isSelectingPointA,
                  ),
                  if (_distance != null) ...[
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.route,
                              size: 18,
                              color: AppColors.darkBlue,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Distance: ${_distance!.toStringAsFixed(2)} km',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '₱${_fare!.toStringAsFixed(2)}',
                            style: GoogleFonts.slackey(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Reset & Calculate Buttons
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Row(
              children: [
                // Reset Button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _resetPoints,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gray,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    icon: const Icon(Icons.refresh, color: AppColors.white),
                    label: Text(
                      'Reset',
                      style: GoogleFonts.slackey(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Confirm Button
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed:
                        _pointA != null &&
                            _pointB != null &&
                            _distance != null &&
                            !_isMatchingRoutes
                        ? _confirmAndReturn
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.darkBlue,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    icon: _isMatchingRoutes
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.white,
                            ),
                          )
                        : const Icon(Icons.check, color: AppColors.white),
                    label: Text(
                      _isMatchingRoutes ? 'Finding Routes...' : 'Confirm Fare',
                      style: GoogleFonts.slackey(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPointRow({
    required String label,
    required bool isActive,
    required Color color,
    required String? areaName,
    required String placeholder,
    required bool isLoading,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isActive ? color : AppColors.lightGray,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            areaName ?? placeholder,
            style: TextStyle(
              color: areaName != null ? AppColors.textPrimary : AppColors.gray,
              fontWeight: areaName != null
                  ? FontWeight.w600
                  : FontWeight.normal,
              fontSize: 13,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (isLoading)
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        if (areaName != null && !isLoading)
          Icon(Icons.check_circle, color: color, size: 20),
      ],
    );
  }

  void _onMapTapped(LatLng point) async {
    if (_isSelectingPointA) {
      setState(() {
        _pointA = point;
        _areaA = null;
        _distance = null;
        _fare = null;
        _routePath = [];
      });
      await _getLocationName(point, true);
      setState(() {
        _isSelectingPointA = false;
      });
    } else {
      setState(() {
        _pointB = point;
        _areaB = null;
        _distance = null;
        _fare = null;
        _routePath = [];
      });
      await _getLocationName(point, false);

      // Automatically get route when both points are set
      if (_pointA != null && _pointB != null) {
        await _getRoute();
      }
    }
  }

  /// Get accurate location name using LocationService reverse geocoding
  /// Format: "Street Name, Area/Barangay"
  Future<void> _getLocationName(LatLng point, bool isPointA) async {
    setState(() {
      _isLoadingArea = true;
    });

    try {
      final result = await _locationService.reverseGeocode(point);

      if (!mounted) return;

      if (result.isSuccess) {
        setState(() {
          if (isPointA) {
            _areaA = result.formattedName;
          } else {
            _areaB = result.formattedName;
          }
        });
      } else {
        setState(() {
          if (isPointA) {
            _areaA = 'Point A';
          } else {
            _areaB = 'Point B';
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (isPointA) {
          _areaA = 'Point A';
        } else {
          _areaB = 'Point B';
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingArea = false;
        });
      }
    }
  }

  /// Get route from OSRM (Open Source Routing Machine)
  /// Returns actual road path with distance, preferring main roads/highways
  /// but allowing smaller roads as fallback
  Future<void> _getRoute() async {
    if (_pointA == null || _pointB == null) return;

    setState(() {
      _isLoadingRoute = true;
    });

    try {
      // OSRM API for driving routes (follows roads)
      // Request alternatives to find routes on main highways
      // alternatives=true: Get alternative routes (OSRM returns up to 2)
      // continue_straight=false: Allow turns to access main roads
      // annotations=true: Get road class information
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${_pointA!.longitude},${_pointA!.latitude};'
        '${_pointB!.longitude},${_pointB!.latitude}'
        '?overview=full&geometries=geojson&alternatives=true&'
        'continue_straight=false&steps=true',
      );

      debugPrint('OSRM URL: $url');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Debug: Print OSRM response
        debugPrint('OSRM Response code: ${data['code']}');
        debugPrint('Number of routes found: ${data['routes']?.length ?? 0}');

        if (data['code'] == 'Ok' && data['routes'].isNotEmpty) {
          // Select best route for jeepney (prefer main roads)
          final route = _selectBestJeepneyRoute(data['routes']);

          // Debug: Print selected route info
          debugPrint('Selected route distance: ${route['distance']} meters');
          debugPrint('Route has geometry: ${route['geometry'] != null}');

          // Get distance in km (OSRM returns meters)
          double distanceKm = route['distance'] / 1000;

          // Parse route geometry (GeoJSON coordinates)
          List<dynamic> coordinates = route['geometry']['coordinates'];
          debugPrint('Number of route points: ${coordinates.length}');

          List<LatLng> routePoints = coordinates.map((coord) {
            return LatLng(coord[1].toDouble(), coord[0].toDouble());
          }).toList();

          // Calculate fare
          // Minimum fare: ₱13 for first 4km
          // Additional: ₱1.80 per km after 4km
          double fare;
          if (distanceKm <= 4) {
            fare = 13.0;
          } else {
            fare = 13.0 + ((distanceKm - 4) * 1.80);
          }

          setState(() {
            _routePath = routePoints;
            _distance = distanceKm;
            _fare = fare;
          });

          debugPrint('Route path updated with ${_routePath.length} points');

          // Fit map to show entire route
          _fitMapToRoute();
        } else {
          debugPrint('No valid routes found or OSRM error: ${data['code']}');
        }
      } else {
        debugPrint('OSRM API error: ${response.statusCode}');
      }
    } catch (e) {
      // If OSRM fails, show error
      debugPrint('Route error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not find route: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoadingRoute = false;
      });
    }
  }

  /// Select the best route for jeepney travel
  /// EXTREMELY biased toward routes using main roads/highways (dark orange roads)
  /// Will avoid white roads (small streets) even if they're much shorter
  Map<String, dynamic> _selectBestJeepneyRoute(List<dynamic> routes) {
    if (routes.length == 1) return routes[0];

    debugPrint('Analyzing ${routes.length} routes for best jeepney path...');

    // Score each route with EXTREME bias toward highways
    Map<String, dynamic>? bestRoute;
    double bestScore = -999999; // Initialize to very negative number

    for (int i = 0; i < routes.length; i++) {
      var route = routes[i];
      double highwayScore = 0;
      double totalSteps = 0;
      int highwaySteps = 0;
      int mainRoadSteps = 0;
      int smallRoadSteps = 0;

      // Analyze route steps to determine road quality
      if (route['legs'] != null && route['legs'].isNotEmpty) {
        for (var leg in route['legs']) {
          if (leg['steps'] != null) {
            for (var step in leg['steps']) {
              totalSteps++;
              String? roadClass = step['name']?.toString().toLowerCase();

              // EXTREME scoring - heavily punish small roads
              if (roadClass != null) {
                // Major highways (dark orange on map)
                if (roadClass.contains('highway') ||
                    roadClass.contains('national') ||
                    roadClass.contains('expressway') ||
                    roadClass.contains('circumferential')) {
                  highwayScore += 1000; // MASSIVE score for highways
                  highwaySteps++;
                }
                // Major avenues/boulevards (yellow-orange on map)
                else if (roadClass.contains('avenue') ||
                    roadClass.contains('boulevard') ||
                    roadClass.contains('main')) {
                  highwayScore += 500; // Very high score for major roads
                  mainRoadSteps++;
                }
                // Regular roads (lighter roads)
                else if (roadClass.contains('road')) {
                  highwayScore += 50; // Low score
                  smallRoadSteps++;
                }
                // Streets (white roads on map - residential)
                else if (roadClass.contains('street') ||
                    roadClass.contains('drive') ||
                    roadClass.contains('lane') ||
                    roadClass.contains('way')) {
                  highwayScore += 5; // Very low score - avoid these
                  smallRoadSteps++;
                } else {
                  highwayScore += 1; // Minimal score for unknown
                  smallRoadSteps++;
                }
              } else {
                highwayScore += 1; // Unknown roads - minimal score
                smallRoadSteps++;
              }
            }
          }
        }
      }

      if (totalSteps == 0) {
        debugPrint('Route $i has no steps, skipping');
        continue;
      }

      // Calculate main road usage ratio
      double mainRoadRatio = (highwaySteps + mainRoadSteps) / totalSteps;

      // EXPONENTIAL bonus for using highways
      // Routes with >50% highway usage get HUGE bonus
      double mainRoadBonus =
          mainRoadRatio * mainRoadRatio * mainRoadRatio * 5000;

      // Total score
      double score = highwayScore + mainRoadBonus;

      // Penalty for using mostly small roads (reduced and conditional)
      // Only penalize if route has very high percentage of small roads
      double smallRoadRatio = smallRoadSteps / totalSteps;
      if (smallRoadRatio > 0.5) {
        // More than 50% small roads
        double smallRoadPenalty = (smallRoadRatio - 0.5) * 2000;
        score -= smallRoadPenalty;
      }

      // MINIMAL distance penalty (almost ignore distance)
      // We want highways even if they're 2x longer
      double distance = route['distance'] / 1000.0; // km
      double distancePenalty = distance * 0.1; // Small penalty
      score -= distancePenalty;

      debugPrint(
        'Route $i: distance=${distance.toStringAsFixed(2)}km, '
        'highways=$highwaySteps, mainRoads=$mainRoadSteps, '
        'smallRoads=$smallRoadSteps, score=$score',
      );

      // Select route with highest score
      if (score > bestScore) {
        bestScore = score;
        bestRoute = route;
        debugPrint('Route $i is now the best route!');
      }
    }

    debugPrint('Selected best route with score: $bestScore');
    return bestRoute ?? routes[0];
  }

  void _fitMapToRoute() {
    if (_routePath.isEmpty) return;

    double minLat = _routePath
        .map((p) => p.latitude)
        .reduce((a, b) => a < b ? a : b);
    double maxLat = _routePath
        .map((p) => p.latitude)
        .reduce((a, b) => a > b ? a : b);
    double minLng = _routePath
        .map((p) => p.longitude)
        .reduce((a, b) => a < b ? a : b);
    double maxLng = _routePath
        .map((p) => p.longitude)
        .reduce((a, b) => a > b ? a : b);

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng)),
        padding: const EdgeInsets.all(80),
      ),
    );
  }

  /// Find jeepney routes that match the user's calculated path
  /// Uses hybrid approach: validates OSRM path, falls back to jeepney-based if needed
  Future<void> _findMatchingJeepneyRoutes() async {
    if (_pointA == null || _pointB == null) {
      _returnWithResults();
      return;
    }

    setState(() {
      _isMatchingRoutes = true;
      _matchedRoutes = [];
      _multiTransferRoutes = [];
      _suggestedRoutes = [];
      _hybridResult = null;
    });

    try {
      final result = await _routeCalculationService.calculateRoutes(
        origin: _pointA!,
        destination: _pointB!,
        osrmPath: _routePath.isNotEmpty ? _routePath : null,
      );

      if (!result.success) {
        throw Exception(result.errorMessage ?? 'Route calculation failed');
      }

      setState(() {
        _matchedRoutes = result.legacyMatches;
        _multiTransferRoutes = result.legacyMultiTransfer;
        _suggestedRoutes = result.hybridSuggestedRoutes;
        _hybridResult = result.hybridResult;
        _isMatchingRoutes = false;
      });

      // Return results directly to fare calculator
      _returnWithResults();
    } catch (e) {
      setState(() {
        _isMatchingRoutes = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to find matching routes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }

      // Return results even if matching failed
      _returnWithResults();
    }
  }

  void _confirmAndReturn() {
    if (_distance == null || _fare == null) return;

    // First, find matching jeepney routes, then return results
    _findMatchingJeepneyRoutes();
  }

  /// Return results to fare calculator screen
  void _returnWithResults() {
    Navigator.pop(context, {
      'from': _areaA ?? 'Point A',
      'to': _areaB ?? 'Point B',
      'distance': _distance,
      'fare': _fare,
      'fromLat': _pointA?.latitude,
      'fromLng': _pointA?.longitude,
      'toLat': _pointB?.latitude,
      'toLng': _pointB?.longitude,
      'pointA': _pointA, // Add point coordinates
      'pointB': _pointB, // Add point coordinates
      'routePath': _routePath, // Add route path
      // Legacy matching results (backward compatibility)
      'matchedRoutes': _matchedRoutes
          .map((m) => {'route': m.route, 'matchPercentage': m.matchPercentage})
          .toList(),
      'multiTransferRoutes': _multiTransferRoutes,
      // New hybrid routing results
      'suggestedRoutes': _suggestedRoutes,
      'hybridResult': _hybridResult,
      'routingSource': _hybridResult?.primarySource.name ?? 'unknown',
      'fallbackUsed': _hybridResult?.fallbackUsed ?? false,
    });
  }

  void _resetPoints() {
    setState(() {
      _pointA = null;
      _pointB = null;
      _areaA = null;
      _areaB = null;
      _distance = null;
      _fare = null;
      _isSelectingPointA = true;
      _routePath = [];
      _matchedRoutes = [];
      _multiTransferRoutes = [];
      _suggestedRoutes = [];
      _hybridResult = null;
    });
    _mapController.move(MapConstants.defaultLocation, MapConstants.defaultZoom);
  }
}
