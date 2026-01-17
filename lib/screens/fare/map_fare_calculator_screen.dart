import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../constants/app_colors.dart';

class MapFareCalculatorScreen extends StatefulWidget {
  const MapFareCalculatorScreen({super.key});

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
  List<LatLng> _routePath = [];

  // TODO: Implement actual jeepney route suggestions based on user pinpoints
  // This will be populated from backend/database later
  List<Map<String, dynamic>> _suggestedRoutes = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.darkBlue),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Map Fare Calculator',
          style: GoogleFonts.slackey(fontSize: 18, color: AppColors.darkBlue),
        ),
      ),
      backgroundColor: AppColors.primary,
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(7.0731, 125.6128), // Davao City
              initialZoom: 14.0,
              onTap: (tapPosition, point) => _onMapTapped(point),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.final_project_cce106',
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
                                  color: Colors.black.withOpacity(0.2),
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
                                  color: Colors.black.withOpacity(0.2),
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
                ],
              ),
            ],
          ),

          // Loading Route Indicator
          if (_isLoadingRoute)
            Positioned(
              top: 100,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
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
                        'Finding route...',
                        style: GoogleFonts.slackey(
                          fontSize: 12,
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
                    color: Colors.black.withOpacity(0.1),
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
                        _pointA != null && _pointB != null && _distance != null
                        ? _confirmAndReturn
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.darkBlue,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    icon: const Icon(Icons.check, color: AppColors.white),
                    label: Text(
                      'Confirm Fare',
                      style: GoogleFonts.slackey(
                        fontSize: 14,
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

  /// Get accurate location name using Nominatim reverse geocoding
  /// Format: "Street Name, Area/Barangay"
  Future<void> _getLocationName(LatLng point, bool isPointA) async {
    setState(() {
      _isLoadingArea = true;
    });

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?'
        'lat=${point.latitude}&lon=${point.longitude}&'
        'format=json&addressdetails=1&zoom=18',
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': 'Lejeepney App'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'];

        // Build accurate location name
        String locationName = _buildLocationName(address);

        setState(() {
          if (isPointA) {
            _areaA = locationName;
          } else {
            _areaB = locationName;
          }
        });
      }
    } catch (e) {
      setState(() {
        if (isPointA) {
          _areaA = 'Point A';
        } else {
          _areaB = 'Point B';
        }
      });
    } finally {
      setState(() {
        _isLoadingArea = false;
      });
    }
  }

  /// Build a readable location name from address components
  /// Priority: Street/Road > Suburb/Barangay > City District
  String _buildLocationName(Map<String, dynamic> address) {
    String streetPart = '';
    String areaPart = '';

    // Get street/road name
    if (address['road'] != null) {
      streetPart = address['road'];
    } else if (address['pedestrian'] != null) {
      streetPart = address['pedestrian'];
    } else if (address['footway'] != null) {
      streetPart = address['footway'];
    } else if (address['path'] != null) {
      streetPart = address['path'];
    }

    // Get area/barangay name
    if (address['suburb'] != null) {
      areaPart = address['suburb'];
    } else if (address['neighbourhood'] != null) {
      areaPart = address['neighbourhood'];
    } else if (address['village'] != null) {
      areaPart = address['village'];
    } else if (address['quarter'] != null) {
      areaPart = address['quarter'];
    } else if (address['city_district'] != null) {
      areaPart = address['city_district'];
    }

    // Combine street and area
    if (streetPart.isNotEmpty && areaPart.isNotEmpty) {
      return '$streetPart, $areaPart';
    } else if (streetPart.isNotEmpty) {
      return streetPart;
    } else if (areaPart.isNotEmpty) {
      return areaPart;
    } else {
      return 'Unknown Location';
    }
  }

  /// Get route from OSRM (Open Source Routing Machine)
  /// Returns actual road path with distance
  Future<void> _getRoute() async {
    if (_pointA == null || _pointB == null) return;

    setState(() {
      _isLoadingRoute = true;
    });

    try {
      // OSRM API for driving routes (follows roads)
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${_pointA!.longitude},${_pointA!.latitude};'
        '${_pointB!.longitude},${_pointB!.latitude}'
        '?overview=full&geometries=geojson',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['code'] == 'Ok' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];

          // Get distance in km (OSRM returns meters)
          double distanceKm = route['distance'] / 1000;

          // Parse route geometry (GeoJSON coordinates)
          List<dynamic> coordinates = route['geometry']['coordinates'];
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

          // Fit map to show entire route
          _fitMapToRoute();
        }
      }
    } catch (e) {
      // If OSRM fails, show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not find route. Please try again.'),
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

  void _confirmAndReturn() {
    if (_distance == null || _fare == null) return;

    // Navigate back to fare calculator with results
    Navigator.pop(context, {
      'from': _areaA ?? 'Point A',
      'to': _areaB ?? 'Point B',
      'distance': _distance,
      'fare': _fare,
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
    });
    _mapController.move(LatLng(7.0731, 125.6128), 14.0);
  }
}
