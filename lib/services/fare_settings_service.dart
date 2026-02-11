import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

/// Centralized fare settings fetched from the admin API.
/// Caches values locally so the app works offline too.
class FareSettingsService extends ChangeNotifier {
  // Singleton
  static FareSettingsService? _instance;
  static FareSettingsService get instance =>
      _instance ??= FareSettingsService._();
  factory FareSettingsService() => instance;
  FareSettingsService._();

  // ─── Cache keys ────────────────────────────────────────
  static const _keyBaseFare = 'fare_settings_base_fare';
  static const _keyFarePerKm = 'fare_settings_fare_per_km';
  static const _keyLastFetch = 'fare_settings_last_fetch';

  // ─── Default values (used until first successful fetch) ─
  static const double defaultBaseFare = 13.0;
  static const double defaultFarePerKm = 1.80;
  static const double baseFareDistance = 4.0; // first N km covered by base fare

  // ─── State ─────────────────────────────────────────────
  double _baseFare = defaultBaseFare;
  double _farePerKm = defaultFarePerKm;
  bool _isLoaded = false;
  bool _isFetching = false;

  // ─── Getters ───────────────────────────────────────────
  double get baseFare => _baseFare;
  double get farePerKm => _farePerKm;
  bool get isLoaded => _isLoaded;

  // ─── Initialize (call once on app start) ───────────────
  Future<void> initialize() async {
    // 1. Load cached values first (instant, works offline)
    await _loadFromCache();
    _isLoaded = true;
    notifyListeners();

    // 2. Then fetch fresh values from API in background
    await fetchFromApi();
  }

  // ─── Fetch from API ────────────────────────────────────
  Future<void> fetchFromApi() async {
    if (_isFetching) return;
    _isFetching = true;

    try {
      final url = '${ApiService.baseUrl}/settings';
      debugPrint('[FareSettings] Fetching from: $url');

      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'Accept': 'application/json',
              'ngrok-skip-browser-warning': 'true',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = json.decode(response.body);

        if (body['success'] == true && body['data'] != null) {
          final data = body['data'];
          final newBaseFare = (data['base_fare'] ?? defaultBaseFare).toDouble();
          final newFarePerKm = (data['fare_per_km'] ?? defaultFarePerKm)
              .toDouble();

          _baseFare = newBaseFare;
          _farePerKm = newFarePerKm;

          await _saveToCache();
          notifyListeners();

          debugPrint(
            '[FareSettings] Updated: baseFare=₱$_baseFare, farePerKm=₱$_farePerKm',
          );
        }
      } else {
        debugPrint('[FareSettings] API returned ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[FareSettings] Fetch failed (using cached/defaults): $e');
    } finally {
      _isFetching = false;
    }
  }

  // ─── Calculate fare (single source of truth) ───────────
  /// Calculate fare for a given distance in km.
  /// Uses the admin-configured base_fare and fare_per_km.
  double calculateFare(double distanceKm, {double? routeBaseFare}) {
    final base = routeBaseFare ?? _baseFare;

    if (distanceKm <= baseFareDistance) {
      return base;
    }

    final additionalKm = distanceKm - baseFareDistance;
    return base + (additionalKm * _farePerKm);
  }

  /// Calculate fare with discount
  double calculateFareWithDiscount(
    double distanceKm, {
    String? discountType,
    double? routeBaseFare,
  }) {
    double fare = calculateFare(distanceKm, routeBaseFare: routeBaseFare);

    if (discountType == 'student' || discountType == 'senior') {
      fare = fare * 0.80; // 20% discount
    }

    return fare;
  }

  // ─── Local cache ───────────────────────────────────────
  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _baseFare = prefs.getDouble(_keyBaseFare) ?? defaultBaseFare;
      _farePerKm = prefs.getDouble(_keyFarePerKm) ?? defaultFarePerKm;
      debugPrint(
        '[FareSettings] Loaded from cache: baseFare=₱$_baseFare, farePerKm=₱$_farePerKm',
      );
    } catch (e) {
      debugPrint('[FareSettings] Cache load failed: $e');
    }
  }

  Future<void> _saveToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_keyBaseFare, _baseFare);
      await prefs.setDouble(_keyFarePerKm, _farePerKm);
      await prefs.setInt(_keyLastFetch, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('[FareSettings] Cache save failed: $e');
    }
  }
}
