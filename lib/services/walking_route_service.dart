// Walking Route Service
// Fetches pedestrian walking paths using server proxy first,
// then falls back to OSRM foot profile or straight line.
//
// The ORS API key is now kept server-side only (in Laravel .env)
// so no API keys are exposed in the mobile client.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'api_service.dart';

/// Service to fetch realistic pedestrian walking paths.
///
/// Strategy: **Server proxy first** → OSRM foot fallback → straight line.
/// The server proxy (Laravel) calls ORS with its own API key.
class WalkingRouteService {
  // Fallback: OSRM foot profile (road-based but still pedestrian-allowed)
  static const String _osrmBaseUrl =
      'https://router.project-osrm.org/route/v1/foot';

  static const Duration _timeout = Duration(seconds: 6);
  static final ApiService _apiService = ApiService();

  // Simple in-memory cache to avoid redundant API calls
  static final Map<String, List<LatLng>> _cache = {};
  static const int _maxCacheSize = 50;

  /// Fetch a realistic pedestrian walking path between two points.
  /// Uses server proxy → OSRM foot fallback → straight line.
  static Future<List<LatLng>> fetchWalkingPath(LatLng from, LatLng to) async {
    // Skip API calls for very short distances (< 30m)
    final distance = const Distance().as(LengthUnit.Meter, from, to);
    if (distance < 30) return [from, to];

    // Check cache first
    final cacheKey =
        '${from.latitude.toStringAsFixed(5)},${from.longitude.toStringAsFixed(5)}'
        '->${to.latitude.toStringAsFixed(5)},${to.longitude.toStringAsFixed(5)}';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    // Try server proxy first (ORS key stays server-side)
    final serverPath = await _fetchFromServer(from, to);
    if (serverPath != null) {
      _addToCache(cacheKey, serverPath);
      return serverPath;
    }

    // Fallback: OSRM foot profile (still pedestrian-aware, no API key needed)
    final osrmPath = await _fetchFromOSRM(from, to);
    if (osrmPath != null) {
      _addToCache(cacheKey, osrmPath);
      return osrmPath;
    }

    // Final fallback: straight line
    debugPrint('[WalkingRouteService] All APIs failed, using straight line');
    return [from, to];
  }

  /// Server proxy — Laravel calls ORS with its own API key.
  /// No API keys exposed in the mobile client.
  static Future<List<LatLng>?> _fetchFromServer(LatLng from, LatLng to) async {
    try {
      final path = await _apiService.fetchWalkingRoute(
        fromLat: from.latitude,
        fromLng: from.longitude,
        toLat: to.latitude,
        toLng: to.longitude,
      );
      if (path.length >= 2) {
        debugPrint('[WalkingRouteService] Server proxy: ${path.length} points');
        return path;
      }
    } catch (e) {
      debugPrint('[WalkingRouteService] Server proxy failed: $e');
    }
    return null;
  }

  /// OSRM foot profile fallback — uses road network with pedestrian-allowed
  /// ways. No API key required (public service).
  static Future<List<LatLng>?> _fetchFromOSRM(LatLng from, LatLng to) async {
    try {
      final url = Uri.parse(
        '$_osrmBaseUrl/'
        '${from.longitude},${from.latitude};'
        '${to.longitude},${to.latitude}'
        '?overview=full&geometries=geojson',
      );

      final response = await http.get(url).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 'Ok' &&
            data['routes'] != null &&
            (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];
          final coords = route['geometry']['coordinates'] as List;
          final path = coords.map<LatLng>((c) {
            return LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble());
          }).toList();
          if (path.length >= 2) {
            debugPrint(
              '[WalkingRouteService] OSRM foot fallback: ${path.length} points',
            );
            return path;
          }
        }
      }
    } catch (e) {
      // Only log if it's not a network error (offline)
      if (!e.toString().contains('SocketException') &&
          !e.toString().contains('Failed host lookup')) {
        debugPrint('[WalkingRouteService] OSRM error: $e');
      }
    }
    return null;
  }

  /// Add a path to cache with LRU eviction
  static void _addToCache(String key, List<LatLng> path) {
    if (_cache.length >= _maxCacheSize) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = path;
  }

  /// Fetch walking paths for multiple segment pairs in parallel
  /// Returns a map of segment index → walking path
  static Future<Map<int, List<LatLng>>> fetchWalkingPathsBatch(
    List<(LatLng from, LatLng to)> segments,
  ) async {
    final results = <int, List<LatLng>>{};

    // Fetch all paths concurrently
    final futures = <Future<void>>[];
    for (int i = 0; i < segments.length; i++) {
      final (from, to) = segments[i];
      futures.add(
        fetchWalkingPath(from, to).then((path) {
          results[i] = path;
        }),
      );
    }

    await Future.wait(futures);
    return results;
  }

  /// Clear the walking route cache
  static void clearCache() {
    _cache.clear();
  }
}
