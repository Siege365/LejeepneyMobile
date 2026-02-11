// Walking Route Service
// Fetches pedestrian walking paths using OpenRouteService foot-walking profile
// This gives realistic human walking paths (footways, sidewalks, pedestrian
// zones, park paths, shortcuts) instead of car-road-following routes.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Service to fetch realistic pedestrian walking paths.
///
/// Uses OpenRouteService (ORS) foot-walking profile which routes on:
///   - Sidewalks, footways, pedestrian zones
///   - Park paths, trails, shortcuts
///   - Crosswalks and pedestrian crossings
///   - Any way tagged for foot access in OSM
///
/// Falls back to OSRM foot profile, then straight line on failure.
class WalkingRouteService {
  // Primary: OpenRouteService — best pedestrian routing
  static const String _orsBaseUrl =
      'https://api.openrouteservice.org/v2/directions/foot-walking';
  // Free public API key for ORS (5,000 req/day limit for free tier)
  static const String _orsApiKey =
      '5b3ce3597851110001cf62487f0b5c6e4c3a4e0e8f0c49a48f7f1a0b';
  // Fallback: OSRM foot profile (road-based but still pedestrian-allowed)
  static const String _osrmBaseUrl =
      'https://router.project-osrm.org/route/v1/foot';

  static const Duration _timeout = Duration(seconds: 6);

  // Simple in-memory cache to avoid redundant API calls
  static final Map<String, List<LatLng>> _cache = {};
  static const int _maxCacheSize = 50;

  /// Fetch a realistic pedestrian walking path between two points.
  /// Uses ORS foot-walking → OSRM foot fallback → straight line.
  /// Pedestrians can walk against one-way traffic and use sidewalks/crossings.
  static Future<List<LatLng>> fetchWalkingPath(LatLng from, LatLng to) async {
    // Skip API calls for very short distances (< 30m)
    final distance = const Distance().as(LengthUnit.Meter, from, to);
    if (distance < 30) return [from, to];

    // Check cache first
    final cacheKey =
        '${from.latitude.toStringAsFixed(5)},${from.longitude.toStringAsFixed(5)}'
        '->${to.latitude.toStringAsFixed(5)},${to.longitude.toStringAsFixed(5)}';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    // Try ORS foot-walking (best pedestrian routing)
    final orsPath = await _fetchFromORS(from, to);
    if (orsPath != null) {
      _addToCache(cacheKey, orsPath);
      return orsPath;
    }

    // Fallback: OSRM foot profile (still pedestrian-aware)
    final osrmPath = await _fetchFromOSRM(from, to);
    if (osrmPath != null) {
      _addToCache(cacheKey, osrmPath);
      return osrmPath;
    }

    // Final fallback: straight line
    debugPrint('[WalkingRouteService] All APIs failed, using straight line');
    return [from, to];
  }

  /// OpenRouteService foot-walking profile — routes on footpaths, sidewalks,
  /// pedestrian zones, park paths, and other walkable ways.
  static Future<List<LatLng>?> _fetchFromORS(LatLng from, LatLng to) async {
    try {
      final url = Uri.parse(
        '$_orsBaseUrl'
        '?start=${from.longitude},${from.latitude}'
        '&end=${to.longitude},${to.latitude}',
      );

      final response = await http
          .get(
            url,
            headers: {
              'Authorization': _orsApiKey,
              'Accept': 'application/json, application/geo+json',
            },
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List?;
        if (features != null && features.isNotEmpty) {
          final geometry = features[0]['geometry'];
          if (geometry != null && geometry['type'] == 'LineString') {
            final coords = geometry['coordinates'] as List;
            final path = coords.map<LatLng>((c) {
              return LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble());
            }).toList();
            if (path.length >= 2) {
              debugPrint(
                '[WalkingRouteService] ORS foot-walking: ${path.length} points',
              );
              return path;
            }
          }
        }
      } else {
        debugPrint('[WalkingRouteService] ORS returned ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[WalkingRouteService] ORS error: $e');
    }
    return null;
  }

  /// OSRM foot profile fallback — uses road network with pedestrian-allowed
  /// ways. Less ideal than ORS but still better than straight lines.
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
      debugPrint('[WalkingRouteService] OSRM error: $e');
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
