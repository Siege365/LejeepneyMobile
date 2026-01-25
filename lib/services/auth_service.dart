// Authentication Service - Handles login, register, logout with Laravel API
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class AuthException implements Exception {
  final String message;
  final Map<String, dynamic>? errors;

  AuthException(this.message, {this.errors});

  @override
  String toString() => message;
}

class AuthService {
  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // ========== API URL CONFIGURATION ==========
  // Must match your Laravel API setup

  // Local IP for device testing (run 'ipconfig' to find)
  static const String _localIp = '172.19.25.44';
  static const String _port = '8000';

  // ngrok URL for physical device testing through firewall
  static const String _ngrokUrl =
      'https://heterochromous-lilli-luetically.ngrok-free.dev';

  // Auth endpoints are at /api (not /api/v1)
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:$_port/api';
    }
    if (!kIsWeb && Platform.isAndroid) {
      // Use ngrok for physical device
      return '$_ngrokUrl/api';
    }
    return 'http://localhost:$_port/api';
  }

  // Storage keys
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';

  // HTTP timeout
  static const Duration _timeout = Duration(seconds: 15);

  // ========== REGISTER ==========
  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    String? phone,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/register'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'name': name,
              'email': email,
              'password': password,
              'password_confirmation': passwordConfirmation,
              if (phone != null && phone.isNotEmpty) 'phone': phone,
            }),
          )
          .timeout(_timeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 201 && data['success'] == true) {
        // Save token and user data
        await _saveToken(data['token']);
        await _saveUser(data['user']);
        return UserModel.fromJson(data['user']);
      } else {
        // Handle validation errors
        final message = data['message'] ?? 'Registration failed';
        final errors = data['errors'] as Map<String, dynamic>?;
        throw AuthException(message, errors: errors);
      }
    } on SocketException {
      throw AuthException('No internet connection');
    } on FormatException catch (e) {
      debugPrint('JSON Parse Error: $e');
      throw AuthException('Server returned invalid response');
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Registration failed: $e');
    }
  }

  // ========== LOGIN ==========
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/login'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(_timeout);

      debugPrint('Login URL: $baseUrl/login');
      debugPrint('Login Status: ${response.statusCode}');
      debugPrint('Login Response: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        // Save token and user data
        await _saveToken(data['token']);
        await _saveUser(data['user']);
        return UserModel.fromJson(data['user']);
      } else {
        // Handle error response
        final message = data['message'] ?? 'Login failed';
        final errors = data['errors'] as Map<String, dynamic>?;
        throw AuthException(message, errors: errors);
      }
    } on SocketException {
      throw AuthException('No internet connection');
    } on FormatException catch (e) {
      debugPrint('JSON Parse Error: $e');
      throw AuthException('Server returned invalid response');
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Login failed: $e');
    }
  }

  // ========== LOGOUT ==========
  Future<void> logout() async {
    try {
      final token = await getToken();
      if (token != null) {
        // Call logout endpoint to invalidate token on server
        await http
            .post(
              Uri.parse('$baseUrl/logout'),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                'Authorization': 'Bearer $token',
              },
            )
            .timeout(_timeout);
      }
    } catch (e) {
      // Even if server logout fails, clear local data
      debugPrint('Logout API call failed: $e');
    } finally {
      // Always clear local auth data
      await _clearAuth();
    }
  }

  // ========== GET CURRENT USER ==========
  Future<UserModel?> getCurrentUser() async {
    try {
      final token = await getToken();
      if (token == null) return null;

      final response = await http
          .get(
            Uri.parse('$baseUrl/user'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['user'] != null) {
          final user = UserModel.fromJson(data['user']);
          await _saveUser(data['user']); // Update cached user data
          return user;
        }
      }

      // Token is invalid, clear auth
      if (response.statusCode == 401) {
        await _clearAuth();
      }

      return null;
    } catch (e) {
      debugPrint('Get current user failed: $e');
      return null;
    }
  }

  // ========== TOKEN MANAGEMENT ==========

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  // ========== USER DATA MANAGEMENT ==========

  Future<void> _saveUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user));
  }

  Future<UserModel?> getCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString(_userKey);
    if (userData != null) {
      return UserModel.fromJson(jsonDecode(userData));
    }
    return null;
  }

  // ========== AUTH STATE ==========

  Future<void> _clearAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Check if user is logged in and token is valid
  Future<bool> validateSession() async {
    final user = await getCurrentUser();
    return user != null;
  }
}

// Helper function for debugging
void debugPrint(String message) {
  if (kIsWeb || !kIsWeb) {
    // ignore: avoid_print
    print('[AuthService] $message');
  }
}
