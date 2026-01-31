// Location Service - Consolidates all location-related logic
// Used by: search_screen, map_fare_calculator_screen, landmarks_screen

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Result of a location operation
class LocationResult {
  final LatLng? location;
  final String? address;
  final String? error;
  final bool hasPermission;

  LocationResult({
    this.location,
    this.address,
    this.error,
    this.hasPermission = true,
  });

  bool get isSuccess => location != null && error == null;
}

/// Result of a geocoding operation
class GeocodingResult {
  final String? displayName;
  final String? streetName;
  final String? areaName;
  final String? error;

  GeocodingResult({
    this.displayName,
    this.streetName,
    this.areaName,
    this.error,
  });

  bool get isSuccess =>
      (displayName != null || streetName != null) && error == null;

  /// Get formatted location name (Street, Area)
  String get formattedName {
    if (streetName != null && areaName != null) {
      return '$streetName, $areaName';
    }
    return streetName ?? areaName ?? displayName ?? 'Unknown Location';
  }
}

/// Search result from place search
class PlaceSearchResult {
  final double latitude;
  final double longitude;
  final String name;
  final String displayName;
  final String? type;

  PlaceSearchResult({
    required this.latitude,
    required this.longitude,
    required this.name,
    required this.displayName,
    this.type,
  });

  LatLng get latLng => LatLng(latitude, longitude);
}

/// Centralized location service for the app
class LocationService {
  // Singleton pattern
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  // Cache for geocoding results to reduce API calls
  final Map<String, GeocodingResult> _geocodingCache = {};

  // Default location (Davao City center)
  static const LatLng defaultLocation = LatLng(7.0731, 125.6128);

  // HTTP timeout
  static const Duration _timeout = Duration(seconds: 10);

  // User-Agent for Nominatim API
  static const String _userAgent = 'Lejeepney App';

  // ========== PERMISSION & CURRENT LOCATION ==========

  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Check current permission status
  Future<LocationPermission> checkPermission() async {
    return await Geolocator.checkPermission();
  }

  /// Request location permission
  Future<LocationPermission> requestPermission() async {
    return await Geolocator.requestPermission();
  }

  /// Get current user location with permission handling
  Future<LocationResult> getCurrentLocation({
    LocationAccuracy accuracy = LocationAccuracy.high,
  }) async {
    try {
      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationResult(
          error: 'Location services are disabled',
          hasPermission: false,
        );
      }

      // Check and request permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return LocationResult(
            error: 'Location permission denied',
            hasPermission: false,
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return LocationResult(
          error:
              'Location permission permanently denied. Please enable in settings.',
          hasPermission: false,
        );
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: accuracy,
      ).timeout(_timeout);

      final location = LatLng(position.latitude, position.longitude);

      // Get address for the location
      final geocoding = await reverseGeocode(location);

      return LocationResult(
        location: location,
        address: geocoding.formattedName,
        hasPermission: true,
      );
    } catch (e) {
      _debugLog('Failed to get current location: $e');
      return LocationResult(error: 'Failed to get location: $e');
    }
  }

  /// Get current position without address lookup (faster)
  Future<LocationResult> getCurrentPosition({
    LocationAccuracy accuracy = LocationAccuracy.high,
  }) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationResult(
          error: 'Location services are disabled',
          hasPermission: false,
        );
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return LocationResult(
            error: 'Location permission denied',
            hasPermission: false,
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return LocationResult(
          error: 'Location permission permanently denied',
          hasPermission: false,
        );
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: accuracy,
      ).timeout(_timeout);

      return LocationResult(
        location: LatLng(position.latitude, position.longitude),
        hasPermission: true,
      );
    } catch (e) {
      _debugLog('Failed to get position: $e');
      return LocationResult(error: 'Failed to get position');
    }
  }

  // ========== GEOCODING ==========

  /// Reverse geocode a location to get address details
  Future<GeocodingResult> reverseGeocode(LatLng location) async {
    // Check cache first
    final cacheKey =
        '${location.latitude.toStringAsFixed(5)},${location.longitude.toStringAsFixed(5)}';
    if (_geocodingCache.containsKey(cacheKey)) {
      return _geocodingCache[cacheKey]!;
    }

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?'
        'lat=${location.latitude}&lon=${location.longitude}&'
        'format=json&addressdetails=1&zoom=18',
      );

      final response = await http
          .get(url, headers: {'User-Agent': _userAgent})
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'] as Map<String, dynamic>?;

        final result = GeocodingResult(
          displayName: data['display_name'],
          streetName: _extractStreetName(address),
          areaName: _extractAreaName(address),
        );

        // Cache the result
        _geocodingCache[cacheKey] = result;

        return result;
      } else {
        return GeocodingResult(
          error: 'Geocoding failed: ${response.statusCode}',
        );
      }
    } catch (e) {
      _debugLog('Reverse geocoding error: $e');
      return GeocodingResult(error: 'Geocoding failed');
    }
  }

  /// Extract street name from address components
  String? _extractStreetName(Map<String, dynamic>? address) {
    if (address == null) return null;

    return address['road'] ??
        address['pedestrian'] ??
        address['footway'] ??
        address['path'];
  }

  /// Extract area/barangay name from address components
  String? _extractAreaName(Map<String, dynamic>? address) {
    if (address == null) return null;

    return address['suburb'] ??
        address['neighbourhood'] ??
        address['village'] ??
        address['quarter'] ??
        address['city_district'];
  }

  // ========== PLACE SEARCH ==========

  /// Search for places by query
  Future<List<PlaceSearchResult>> searchPlaces(
    String query, {
    LatLng? nearLocation,
    int limit = 5,
  }) async {
    if (query.trim().isEmpty) return [];

    try {
      // Build query with Davao City bias
      var searchQuery = '$query, Davao City, Philippines';

      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?'
        'q=${Uri.encodeComponent(searchQuery)}&'
        'format=json&'
        'limit=$limit&'
        'addressdetails=1'
        '${nearLocation != null ? '&viewbox=${nearLocation.longitude - 0.1},${nearLocation.latitude + 0.1},${nearLocation.longitude + 0.1},${nearLocation.latitude - 0.1}&bounded=0' : ''}',
      );

      final response = await http
          .get(url, headers: {'User-Agent': _userAgent})
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        return data.map((item) {
          return PlaceSearchResult(
            latitude: double.parse(item['lat']),
            longitude: double.parse(item['lon']),
            name: _extractPlaceName(item),
            displayName: item['display_name'] ?? '',
            type: item['type'],
          );
        }).toList();
      }

      return [];
    } catch (e) {
      _debugLog('Place search error: $e');
      return [];
    }
  }

  /// Extract a clean place name from search result
  String _extractPlaceName(Map<String, dynamic> item) {
    final address = item['address'] as Map<String, dynamic>?;
    if (address == null) {
      return item['display_name']?.split(',').first ?? 'Unknown';
    }

    // Priority: specific place > road > suburb
    return address['amenity'] ??
        address['shop'] ??
        address['building'] ??
        address['road'] ??
        address['suburb'] ??
        item['display_name']?.split(',').first ??
        'Unknown';
  }

  // ========== DISTANCE CALCULATION ==========

  /// Calculate distance between two points in kilometers
  double calculateDistance(LatLng from, LatLng to) {
    const distance = Distance();
    return distance.as(LengthUnit.Kilometer, from, to);
  }

  /// Calculate distance between two points in meters
  double calculateDistanceMeters(LatLng from, LatLng to) {
    const distance = Distance();
    return distance.as(LengthUnit.Meter, from, to);
  }

  // ========== POSITION STREAM ==========

  /// Get a stream of position updates for real-time location tracking
  /// [distanceFilter] Minimum distance (in meters) before an update is triggered
  Stream<Position> getPositionStream({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = 10,
  }) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
      ),
    );
  }

  // ========== UTILITY ==========

  /// Clear geocoding cache
  void clearCache() {
    _geocodingCache.clear();
  }

  /// Debug logging
  void _debugLog(String message) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('[LocationService] $message');
    }
  }
}
