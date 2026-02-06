import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/recent_activity_model.dart';

/// API service for recent activity server communication
class RecentActivityApiService {
  // Use the same URL configuration as ApiService
  static const String _ngrokUrl =
      'https://heterochromous-lilli-luetically.ngrok-free.dev/api/v1';
  static const String _localIp = '172.19.25.44';
  static const String _port = '8000';
  static const String _apiPath = '/api/v1';

  static String get _baseUrl {
    if (kIsWeb) {
      return 'http://localhost:$_port$_apiPath';
    }
    if (!kIsWeb && Platform.isAndroid) {
      return _ngrokUrl;
    }
    return 'http://localhost:$_port$_apiPath';
  }

  static const Duration _timeout = Duration(seconds: 15);
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  /// Get auth headers
  Future<Map<String, String>> _getHeaders() async {
    final token = await _storage.read(key: 'auth_token');
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'ngrok-skip-browser-warning': 'true',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Check if user is authenticated
  Future<bool> isAuthenticated() async {
    final token = await _storage.read(key: 'auth_token');
    return token != null && token.isNotEmpty;
  }

  /// GET /recent-activities - Fetch activities from server
  Future<ApiResponse<List<RecentActivityModel>>> getActivities({
    int limit = 20,
    String? activityType,
  }) async {
    try {
      final headers = await _getHeaders();

      final queryParams = <String, String>{
        'limit': limit.toString(),
        if (activityType != null) 'activity_type': activityType,
      };

      final uri = Uri.parse(
        '$_baseUrl/recent-activities',
      ).replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: headers).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final activities = (data['data'] as List)
            .map((json) => RecentActivityModel.fromJson(json))
            .toList();
        return ApiResponse.success(activities);
      } else if (response.statusCode == 401) {
        return ApiResponse.error('Unauthorized');
      } else {
        return ApiResponse.error(
          'Failed to fetch activities: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Error fetching activities: $e');
      return ApiResponse.error('Network error: $e');
    }
  }

  /// POST /recent-activities - Create single activity
  Future<ApiResponse<RecentActivityModel>> createActivity(
    RecentActivityModel activity,
  ) async {
    try {
      final headers = await _getHeaders();

      final response = await http
          .post(
            Uri.parse('$_baseUrl/recent-activities'),
            headers: headers,
            body: jsonEncode(activity.toJson()),
          )
          .timeout(_timeout);

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final created = RecentActivityModel.fromJson(data['data']);
        return ApiResponse.success(created);
      } else {
        return ApiResponse.error(
          'Failed to create activity: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Error creating activity: $e');
      return ApiResponse.error('Network error: $e');
    }
  }

  /// POST /recent-activities/batch - Batch sync activities
  Future<ApiResponse<List<int>>> batchSync(
    List<RecentActivityModel> activities,
  ) async {
    try {
      final headers = await _getHeaders();
      final requestBody = {
        'activities': activities.map((a) => a.toJson()).toList(),
      };

      debugPrint('Batch sync request: ${activities.length} activities');
      debugPrint('Request URL: $_baseUrl/recent-activities/batch');

      final response = await http
          .post(
            Uri.parse('$_baseUrl/recent-activities/batch'),
            headers: headers,
            body: jsonEncode(requestBody),
          )
          .timeout(_timeout);

      debugPrint('Batch sync response: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          debugPrint('Decoded data: $data');
          debugPrint('Data type: ${data.runtimeType}');
          debugPrint('Data keys: ${data is Map ? data.keys : "not a map"}');

          // Try to extract IDs from various possible response structures
          List<int> serverIds = [];

          if (data is Map) {
            // Try data.data.ids structure (array of IDs only)
            if (data['data'] != null && data['data']['ids'] != null) {
              serverIds = (data['data']['ids'] as List)
                  .map((id) => id is int ? id : int.parse(id.toString()))
                  .toList();
            }
            // Try data.ids structure (array of IDs only)
            else if (data['ids'] != null) {
              serverIds = (data['ids'] as List)
                  .map((id) => id is int ? id : int.parse(id.toString()))
                  .toList();
            }
            // Try if data.data is array of activity objects with id field
            else if (data['data'] is List) {
              serverIds = (data['data'] as List)
                  .map((item) {
                    if (item is Map<String, dynamic>) {
                      final id = item['id'];
                      return id is int ? id : int.parse(id.toString());
                    }
                    return 0; // Fallback
                  })
                  .where((id) => id > 0)
                  .toList();
            }
          }

          debugPrint('Extracted server IDs: $serverIds');
          return ApiResponse.success(serverIds);
        } catch (e) {
          debugPrint('Error parsing batch response: $e');
          return ApiResponse.error('Failed to parse response: $e');
        }
      } else {
        debugPrint(
          'Batch sync failed with status ${response.statusCode}: ${response.body}',
        );
        return ApiResponse.error(
          'Failed to batch sync: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Error batch syncing: $e');
      return ApiResponse.error('Network error: $e');
    }
  }

  /// DELETE /recent-activities/{id} - Delete specific activity
  Future<ApiResponse<bool>> deleteActivity(int serverId) async {
    try {
      final headers = await _getHeaders();

      final response = await http
          .delete(
            Uri.parse('$_baseUrl/recent-activities/$serverId'),
            headers: headers,
          )
          .timeout(_timeout);

      if (response.statusCode == 200 || response.statusCode == 204) {
        return ApiResponse.success(true);
      } else if (response.statusCode == 401) {
        return ApiResponse.error('Unauthorized');
      } else {
        return ApiResponse.error('Failed to delete: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error deleting activity: $e');
      return ApiResponse.error('Network error: $e');
    }
  }

  /// DELETE /recent-activities/clear - Clear all activities
  Future<ApiResponse<bool>> clearAll() async {
    try {
      final headers = await _getHeaders();

      final response = await http
          .delete(
            Uri.parse('$_baseUrl/recent-activities/clear'),
            headers: headers,
          )
          .timeout(_timeout);

      if (response.statusCode == 200 || response.statusCode == 204) {
        return ApiResponse.success(true);
      } else if (response.statusCode == 401) {
        return ApiResponse.error('Unauthorized');
      } else {
        return ApiResponse.error('Failed to clear: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error clearing activities: $e');
      return ApiResponse.error('Network error: $e');
    }
  }
}

/// Generic API response wrapper
class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? error;

  ApiResponse._({required this.success, this.data, this.error});

  factory ApiResponse.success(T data) {
    return ApiResponse._(success: true, data: data);
  }

  factory ApiResponse.error(String message) {
    return ApiResponse._(success: false, error: message);
  }
}
