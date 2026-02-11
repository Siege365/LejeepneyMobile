import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode, kIsWeb;
import 'package:http/http.dart' as http;
import '../models/landmark.dart';
import '../models/jeepney_route.dart';
import 'fare_settings_service.dart';

class ApiService {
  // ========== CONFIGURE YOUR API URL HERE ==========
  // Your computer's local IP (run 'ipconfig' to find it)
  static const String _localIp = '172.19.25.44';

  // Laravel port (usually 8000 for php artisan serve)
  static const String _port = '8000';

  // API version path
  static const String _apiPath = '/api/v1';

  // ngrok URL (when using ngrok for physical device testing)
  // SECURITY: Uses HTTPS for encrypted connections
  // Get this from running: ngrok http 8000
  static const String _ngrokUrl =
      'https://heterochromous-lilli-luetically.ngrok-free.dev/api/v1';

  // URLs for different environments
  // ignore: unused_field - Reserved for emulator testing
  static const String _baseUrlEmulator =
      'http://10.0.2.2:$_port$_apiPath'; // Android Emulator
  static const String _baseUrlWeb =
      'http://localhost:$_port$_apiPath'; // Chrome/Web
  // ignore: unused_field - Reserved for physical device testing
  static const String _baseUrlDevice =
      'http://$_localIp:$_port$_apiPath'; // Physical device (local network)

  static String get baseUrl {
    if (kIsWeb) {
      // SECURITY: Use HTTPS in production
      return kDebugMode ? _baseUrlWeb : 'https://localhost:$_port$_apiPath';
    }
    if (Platform.isAndroid) {
      // For physical device with firewall issues, use ngrok (already HTTPS):
      return _ngrokUrl;

      // For local network (no firewall):
      // return _baseUrlDevice; // Use _baseUrlEmulator for Android Emulator
    }
    return kDebugMode ? _baseUrlWeb : 'https://localhost:$_port$_apiPath';
  }

  // Singleton pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // HTTP client with timeout
  final http.Client _client = http.Client();
  static const Duration _timeout = Duration(
    seconds: 90,
  ); // Increased for large route data
  static const int _maxRetries = 3;

  // Helper method to get standard headers with ngrok bypass
  Map<String, String> _getHeaders({Map<String, String>? additional}) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'ngrok-skip-browser-warning': 'true',
    };
    if (additional != null) {
      headers.addAll(additional);
    }
    return headers;
  }

  // ========== LANDMARKS API ==========

  /// Fetch all landmarks with optional filters
  Future<List<Landmark>> fetchAllLandmarks({
    String? category,
    bool? featured,
    String? search,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (category != null && category.isNotEmpty && category != 'All') {
        queryParams['category'] = Landmark.toCategoryApi(category);
      }
      if (featured != null && featured) {
        queryParams['featured'] = 'true';
      }
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final uri = Uri.parse(
        '$baseUrl/landmarks',
      ).replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await _client
          .get(uri, headers: _getHeaders())
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return (data['data'] as List)
              .map((json) => Landmark.fromJson(json))
              .toList();
        }
      }

      throw ApiException('Failed to fetch landmarks: ${response.statusCode}');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: $e');
    }
  }

  /// Fetch featured landmarks only
  Future<List<Landmark>> fetchFeaturedLandmarks() async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/landmarks/featured'), headers: _getHeaders())
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return (data['data'] as List)
              .map((json) => Landmark.fromJson(json))
              .toList();
        }
      }

      throw ApiException('Failed to fetch featured landmarks');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: $e');
    }
  }

  /// Fetch landmarks by category
  Future<List<Landmark>> fetchLandmarksByCategory(String category) async {
    try {
      final apiCategory = Landmark.toCategoryApi(category);
      final response = await _client
          .get(
            Uri.parse('$baseUrl/landmarks/category/$apiCategory'),
            headers: _getHeaders(),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return (data['data'] as List)
              .map((json) => Landmark.fromJson(json))
              .toList();
        }
      }

      throw ApiException('Failed to fetch landmarks by category');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: $e');
    }
  }

  /// Fetch landmarks near a location
  Future<List<Landmark>> fetchNearbyLandmarks({
    required double latitude,
    required double longitude,
    double radius = 5.0, // km
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/landmarks/nearby'),
            headers: _getHeaders(),
            body: json.encode({
              'latitude': latitude,
              'longitude': longitude,
              'radius': radius,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return (data['data'] as List)
              .map((json) => Landmark.fromJson(json))
              .toList();
        }
      }

      throw ApiException('Failed to fetch nearby landmarks');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: $e');
    }
  }

  /// Fetch a single landmark by ID
  Future<Landmark> fetchLandmarkById(int id) async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/landmarks/$id'), headers: _getHeaders())
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return Landmark.fromJson(data['data']);
        }
      }

      throw ApiException('Failed to fetch landmark');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: $e');
    }
  }

  // ========== ROUTES API ==========

  /// Fetch all jeepney routes with retry logic
  Future<List<JeepneyRoute>> fetchAllRoutes() async {
    int retryCount = 0;
    Exception? lastError;

    while (retryCount < _maxRetries) {
      try {
        debugPrint(
          '[API] Fetching routes (attempt ${retryCount + 1}/$_maxRetries)...',
        );

        final response = await _client
            .get(
              Uri.parse('$baseUrl/routes'),
              headers: _getHeaders(additional: {'Connection': 'keep-alive'}),
            )
            .timeout(_timeout);

        if (response.statusCode == 200) {
          debugPrint(
            '[API] Routes response received (${response.body.length} bytes)',
          );

          // Parse in try-catch to handle partial JSON
          try {
            final data = json.decode(response.body);
            if (data['success'] == true && data['data'] != null) {
              final routes = (data['data'] as List)
                  .map((json) => JeepneyRoute.fromJson(json))
                  .toList();
              debugPrint('[API] Successfully parsed ${routes.length} routes');
              return routes;
            }
          } on FormatException catch (e) {
            debugPrint('[API] JSON parsing failed: ${e.message}');
            throw ApiException(
              'Incomplete data received from server. Please try again.',
            );
          }
        }

        throw ApiException(
          'Failed to fetch routes (status: ${response.statusCode})',
        );
      } on SocketException catch (e) {
        lastError = e;
        debugPrint('[API] Network error (attempt ${retryCount + 1}): $e');
        retryCount++;
        if (retryCount < _maxRetries) {
          await Future.delayed(
            Duration(seconds: 2 * retryCount),
          ); // Exponential backoff
          continue;
        }
      } on http.ClientException catch (e) {
        lastError = e;
        debugPrint('[API] Connection error (attempt ${retryCount + 1}): $e');
        retryCount++;
        if (retryCount < _maxRetries) {
          await Future.delayed(Duration(seconds: 2 * retryCount));
          continue;
        }
      } on TimeoutException catch (e) {
        lastError = e;
        debugPrint('[API] Timeout (attempt ${retryCount + 1}): $e');
        retryCount++;
        if (retryCount < _maxRetries) {
          await Future.delayed(Duration(seconds: 2 * retryCount));
          continue;
        }
      } catch (e) {
        if (e is ApiException) rethrow;
        debugPrint('[API] Unexpected error: $e');
        throw ApiException('Network error: $e');
      }
    }

    throw ApiException(
      'Failed to fetch routes after $_maxRetries attempts. ${lastError != null ? 'Last error: $lastError' : 'Please check your internet connection.'}',
    );
  }

  /// Fetch a single route by ID
  Future<JeepneyRoute> fetchRouteById(int id) async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/routes/$id'), headers: _getHeaders())
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return JeepneyRoute.fromJson(data['data']);
        }
      }

      throw ApiException('Failed to fetch route');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: $e');
    }
  }

  /// Find routes between two points
  Future<List<JeepneyRoute>> findRoutes({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
    double tolerance = 0.5, // km
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/routes/find'),
            headers: _getHeaders(),
            body: json.encode({
              'from_lat': fromLat,
              'from_lng': fromLng,
              'to_lat': toLat,
              'to_lng': toLng,
              'tolerance': tolerance,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return (data['data'] as List)
              .map((json) => JeepneyRoute.fromJson(json))
              .toList();
        }
      }

      throw ApiException('Failed to find routes');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: $e');
    }
  }

  // ========== FARE API (if implemented) ==========

  /// Calculate fare between two points
  Future<FareResult> calculateFare({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
    required double distance,
    String? discountType, // 'student', 'senior', or null
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/fares/calculate'),
            headers: _getHeaders(),
            body: json.encode({
              'from': {'lat': fromLat, 'lng': fromLng},
              'to': {'lat': toLat, 'lng': toLng},
              'distance': distance,
              'discount_type': discountType,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return FareResult.fromJson(data);
      }

      throw ApiException('Failed to calculate fare');
    } catch (e) {
      if (e is ApiException) rethrow;
      // Fallback to local calculation if API fails
      return _calculateFareLocally(distance, discountType);
    }
  }

  /// Local fare calculation fallback
  FareResult _calculateFareLocally(double distance, String? discountType) {
    final fareService = FareSettingsService.instance;
    final double baseFare = fareService.baseFare;
    final double perKmRate = fareService.farePerKm;
    const double minimumDistance = 4.0;

    double fare;
    if (distance <= minimumDistance) {
      fare = baseFare;
    } else {
      fare = baseFare + ((distance - minimumDistance) * perKmRate);
    }

    double discount = 0;
    if (discountType == 'student' || discountType == 'senior') {
      discount = fare * 0.20;
      fare = fare - discount;
    }

    return FareResult(
      fare: fare,
      baseFare: baseFare,
      additionalFare: fare - baseFare + discount,
      distance: distance,
      discount: discount,
      finalFare: fare,
    );
  }

  /// Fetch current fare rates from /settings endpoint
  Future<FareRates> fetchFareRates() async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/settings'), headers: _getHeaders())
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body['success'] == true && body['data'] != null) {
          return FareRates.fromJson(body['data']);
        }
      }

      // Return default rates if API fails
      return FareRates.defaults();
    } catch (e) {
      // Return default rates on error
      return FareRates.defaults();
    }
  }

  // ========== HEALTH CHECK ==========

  /// Check if the API is reachable
  Future<bool> healthCheck() async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/landmarks'), headers: _getHeaders())
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}

// ========== EXCEPTION CLASS ==========

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}

// ========== FARE RESULT MODEL ==========

class FareResult {
  final double fare;
  final double baseFare;
  final double additionalFare;
  final double distance;
  final double discount;
  final double finalFare;

  FareResult({
    required this.fare,
    required this.baseFare,
    required this.additionalFare,
    required this.distance,
    required this.discount,
    required this.finalFare,
  });

  factory FareResult.fromJson(Map<String, dynamic> json) {
    return FareResult(
      fare: (json['fare'] ?? 0).toDouble(),
      baseFare: (json['base_fare'] ?? 13.0).toDouble(),
      additionalFare: (json['additional_fare'] ?? 0).toDouble(),
      distance: (json['distance'] ?? 0).toDouble(),
      discount: (json['discount'] ?? 0).toDouble(),
      finalFare: (json['final_fare'] ?? json['fare'] ?? 0).toDouble(),
    );
  }
}

// ========== FARE RATES MODEL ==========

class FareRates {
  final double baseFare;
  final double perKmRate;
  final double studentDiscount;
  final double seniorDiscount;

  FareRates({
    required this.baseFare,
    required this.perKmRate,
    required this.studentDiscount,
    required this.seniorDiscount,
  });

  factory FareRates.fromJson(Map<String, dynamic> json) {
    return FareRates(
      baseFare: (json['base_fare'] ?? 13.0).toDouble(),
      perKmRate: (json['fare_per_km'] ?? json['per_km_rate'] ?? 1.80)
          .toDouble(),
      studentDiscount: (json['student_discount'] ?? 20.0).toDouble(),
      seniorDiscount: (json['senior_discount'] ?? 20.0).toDouble(),
    );
  }

  factory FareRates.defaults() {
    return FareRates(
      baseFare: 13.0,
      perKmRate: 1.80,
      studentDiscount: 20.0,
      seniorDiscount: 20.0,
    );
  }
}
