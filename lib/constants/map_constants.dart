// Map Constants - Centralized configuration for map-related values
// Follows Single Responsibility Principle - one place for all map defaults

import 'package:latlong2/latlong.dart';

/// Centralized map configuration constants
class MapConstants {
  MapConstants._();

  // ========== DEFAULT LOCATION ==========
  /// Davao City center coordinates (default fallback location)
  static const double defaultLatitude = 7.0731;
  static const double defaultLongitude = 125.6128;

  /// Default location as LatLng
  static LatLng get defaultLocation =>
      const LatLng(defaultLatitude, defaultLongitude);

  /// Default location name
  static const String defaultLocationName = 'Davao City, Philippines';
  static const String defaultLocationWithSuffix =
      'Davao City, Philippines (Default)';

  // ========== ZOOM LEVELS ==========
  static const double defaultZoom = 14.0;
  static const double searchZoom = 16.0;
  static const double userLocationZoom = 15.0;
  static const double routeOverviewZoom = 12.0;

  // ========== LOCATION SETTINGS ==========
  /// Distance filter for location updates (in meters)
  static const int locationDistanceFilter = 10;

  /// Timeouts for GPS acquisition
  static const Duration highAccuracyTimeout = Duration(seconds: 15);
  static const Duration mediumAccuracyTimeout = Duration(seconds: 20);
  static const Duration lowAccuracyTimeout = Duration(seconds: 25);

  // ========== ROUTE DISPLAY ==========
  /// Distance between direction arrow markers (in meters)
  static const double arrowIntervalMeters = 1000.0; // 1 km

  /// Route polyline width
  static const double routeStrokeWidth = 7.0;
  static const double routeBorderWidth = 2.0;

  // ========== MAP BOUNDS PADDING ==========
  static const double routePadding = 60.0;
  static const double singleRoutePadding = 50.0;

  // ========== TILE LAYER ==========
  static const String osmTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String appUserAgent = 'com.example.final_project_cce106';

  // ========== NOMINATIM API ==========
  static const String nominatimBaseUrl = 'https://nominatim.openstreetmap.org';
  static const String nominatimUserAgent = 'Lejeepney App';
}
