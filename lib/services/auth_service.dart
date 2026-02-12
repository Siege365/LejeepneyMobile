// Authentication Service - Handles login, register, logout with Laravel API
// SECURITY HARDENED VERSION - Uses encrypted storage, input sanitization, rate limiting
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../utils/security_utils.dart';
import 'recent_activity_service_v2.dart';

class AuthException implements Exception {
  final String message;
  final Map<String, dynamic>? errors;
  final bool isRateLimited;

  AuthException(this.message, {this.errors, this.isRateLimited = false});

  @override
  String toString() => message;
}

class AuthService {
  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // ========== SECURE STORAGE ==========
  // Uses platform-specific encryption (Keychain on iOS, EncryptedSharedPreferences on Android)
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // ========== RATE LIMITING ==========
  static const int _maxLoginAttempts = 5;
  static const Duration _lockoutDuration = Duration(minutes: 15);
  int _loginAttempts = 0;
  DateTime? _lockoutUntil;

  // ========== API URL CONFIGURATION ==========
  // Must match your Laravel API setup

  // Local IP for device testing (run 'ipconfig' to find)
  // ignore: unused_field - Reserved for local network testing
  static const String _localIp = '172.19.25.44';
  static const String _port = '8000';

  // ngrok URL for physical device testing through firewall
  // SECURITY: Using HTTPS for all external connections
  static const String _ngrokUrl =
      'https://heterochromous-lilli-luetically.ngrok-free.dev';

  // Auth endpoints are at /api (not /api/v1)
  static String get baseUrl {
    if (kIsWeb) {
      // SECURITY: Use HTTPS in production
      return kDebugMode
          ? 'http://localhost:$_port/api'
          : 'https://localhost:$_port/api';
    }
    if (!kIsWeb && Platform.isAndroid) {
      // Use ngrok for physical device (already HTTPS)
      return '$_ngrokUrl/api';
    }
    return kDebugMode
        ? 'http://localhost:$_port/api'
        : 'https://localhost:$_port/api';
  }

  // Storage keys
  static const String _tokenKey = 'auth_token';
  static const String _tokenExpiryKey = 'token_expiry';
  static const String _userKey = 'user_data';
  static const String _loginAttemptsKey = 'login_attempts';
  static const String _lockoutKey = 'lockout_until';

  // HTTP timeout - shorter to prevent hanging
  static const Duration _timeout = Duration(seconds: 10);

  // Token expiry - 7 days (should match Laravel Sanctum config)
  static const Duration _tokenLifetime = Duration(days: 7);

  // ========== RATE LIMITING CHECK ==========
  Future<void> _checkRateLimit() async {
    // Load persisted rate limit state
    await _loadRateLimitState();

    if (_lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!)) {
      final remaining = _lockoutUntil!.difference(DateTime.now());
      throw AuthException(
        'Too many login attempts. Please try again in ${remaining.inMinutes} minutes.',
        isRateLimited: true,
      );
    }

    // Reset if lockout has expired
    if (_lockoutUntil != null && DateTime.now().isAfter(_lockoutUntil!)) {
      _loginAttempts = 0;
      _lockoutUntil = null;
      await _clearRateLimitState();
    }
  }

  void _recordLoginAttempt({required bool success}) {
    if (success) {
      _loginAttempts = 0;
      _lockoutUntil = null;
      _clearRateLimitState();
    } else {
      _loginAttempts++;
      if (_loginAttempts >= _maxLoginAttempts) {
        _lockoutUntil = DateTime.now().add(_lockoutDuration);
        _saveRateLimitState();
      }
    }
  }

  Future<void> _loadRateLimitState() async {
    final prefs = await SharedPreferences.getInstance();
    _loginAttempts = prefs.getInt(_loginAttemptsKey) ?? 0;
    final lockoutMs = prefs.getInt(_lockoutKey);
    if (lockoutMs != null) {
      _lockoutUntil = DateTime.fromMillisecondsSinceEpoch(lockoutMs);
    }
  }

  Future<void> _saveRateLimitState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_loginAttemptsKey, _loginAttempts);
    if (_lockoutUntil != null) {
      await prefs.setInt(_lockoutKey, _lockoutUntil!.millisecondsSinceEpoch);
    }
  }

  Future<void> _clearRateLimitState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_loginAttemptsKey);
    await prefs.remove(_lockoutKey);
  }

  // ========== REGISTER ==========
  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    String? phone,
  }) async {
    // SECURITY: Sanitize all inputs
    final sanitizedName = SecurityUtils.sanitizeName(name);
    final sanitizedEmail = SecurityUtils.sanitizeEmail(email);
    final sanitizedPhone = phone != null
        ? SecurityUtils.sanitizePhone(phone)
        : null;

    // SECURITY: Validate inputs using boolean validators
    if (!SecurityUtils.isValidName(sanitizedName)) {
      throw AuthException('Invalid name format');
    }
    if (!SecurityUtils.isValidEmail(sanitizedEmail)) {
      throw AuthException('Invalid email format');
    }
    if (sanitizedPhone != null &&
        sanitizedPhone.isNotEmpty &&
        !SecurityUtils.isValidPhone(sanitizedPhone)) {
      throw AuthException('Invalid phone number format');
    }

    // SECURITY: Validate password strength
    final passwordError = SecurityUtils.validatePasswordSimple(password);
    if (passwordError != null) {
      throw AuthException(passwordError);
    }

    if (password != passwordConfirmation) {
      throw AuthException('Passwords do not match');
    }

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/register'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'ngrok-skip-browser-warning': 'true',
            },
            body: jsonEncode({
              'name': sanitizedName,
              'email': sanitizedEmail,
              'password': password,
              'password_confirmation': passwordConfirmation,
              if (sanitizedPhone != null && sanitizedPhone.isNotEmpty)
                'phone': sanitizedPhone,
            }),
          )
          .timeout(_timeout);

      // SECURITY: Only log in debug mode, never log sensitive data
      SecurityUtils.debugLog('Register status: ${response.statusCode}');

      // Handle rate limiting from server
      if (response.statusCode == 429) {
        throw AuthException(
          'Too many requests. Please wait a moment before trying again.',
          isRateLimited: true,
        );
      }

      final data = jsonDecode(response.body);

      if (response.statusCode == 201 && data['success'] == true) {
        // Save token and user data securely
        await _saveToken(data['token']);
        await _saveUser(data['user']);
        return UserModel.fromJson(data['user']);
      } else {
        // Handle validation errors - don't expose internal details
        final message = data['message'] ?? 'Registration failed';
        final errors = data['errors'] as Map<String, dynamic>?;
        throw AuthException(message, errors: errors);
      }
    } on SocketException {
      throw AuthException('No internet connection');
    } on FormatException {
      SecurityUtils.debugLog('JSON Parse Error in register');
      throw AuthException('Server returned invalid response');
    } catch (e) {
      if (e is AuthException) rethrow;
      SecurityUtils.debugLog('Register error: $e');
      throw AuthException('Registration failed. Please try again.');
    }
  }

  // ========== LOGIN ==========
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    // SECURITY: Check rate limiting before proceeding
    await _checkRateLimit();

    // SECURITY: Sanitize email input
    final sanitizedEmail = SecurityUtils.sanitizeEmail(email);

    // SECURITY: Basic validation using boolean validator
    if (!SecurityUtils.isValidEmail(sanitizedEmail)) {
      throw AuthException('Invalid email format');
    }

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/login'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'ngrok-skip-browser-warning': 'true',
            },
            body: jsonEncode({'email': sanitizedEmail, 'password': password}),
          )
          .timeout(_timeout);

      // SECURITY: Only log non-sensitive data in debug mode
      SecurityUtils.debugLog('Login URL: $baseUrl/login');
      SecurityUtils.debugLog('Login Status: ${response.statusCode}');

      // Handle rate limiting from server
      if (response.statusCode == 429) {
        // Don't count server rate limit as failed attempt
        throw AuthException(
          'Too many requests. Please wait a moment before trying again.',
          isRateLimited: true,
        );
      }

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        // SECURITY: Record successful login (resets rate limit)
        _recordLoginAttempt(success: true);

        // Save token and user data securely
        await _saveToken(data['token']);
        await _saveUser(data['user']);
        return UserModel.fromJson(data['user']);
      } else {
        // SECURITY: Record failed attempt
        _recordLoginAttempt(success: false);

        // Handle error response - generic message for security
        final message = data['message'] ?? 'Invalid credentials';
        throw AuthException(message);
      }
    } on SocketException {
      throw AuthException('No internet connection');
    } on FormatException {
      SecurityUtils.debugLog('JSON Parse Error in login');
      throw AuthException('Server returned invalid response');
    } catch (e) {
      if (e is AuthException) rethrow;
      SecurityUtils.debugLog('Login error: $e');
      throw AuthException('Login failed. Please try again.');
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
                'ngrok-skip-browser-warning': 'true',
              },
            )
            .timeout(_timeout);
      }
    } catch (e) {
      // Even if server logout fails, clear local data
      SecurityUtils.debugLog('Logout API call failed');
    } finally {
      // Clear recent activities before clearing auth
      SecurityUtils.debugLog('Clearing recent activities...');
      final cleared = await RecentActivityServiceV2.clearAll();
      SecurityUtils.debugLog('Activities cleared: $cleared');
      // Always clear local auth data
      await _clearAuth();
    }
  }

  // ========== GET CURRENT USER ==========
  Future<UserModel?> getCurrentUser() async {
    try {
      // SECURITY: Check token expiry first
      if (await _isTokenExpired()) {
        SecurityUtils.debugLog('Token expired, clearing auth');
        await _clearAuth();
        return null;
      }

      final token = await getToken();
      if (token == null) return null;

      final response = await http
          .get(
            Uri.parse('$baseUrl/user'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
              'ngrok-skip-browser-warning': 'true',
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
      SecurityUtils.debugLog('Get current user failed');
      return null;
    }
  }

  // ========== SECURE TOKEN MANAGEMENT ==========

  Future<void> _saveToken(String token) async {
    // SECURITY: Store token in encrypted storage
    await _secureStorage.write(key: _tokenKey, value: token);

    // SECURITY: Store token expiry time
    final expiry = DateTime.now().add(_tokenLifetime);
    await _secureStorage.write(
      key: _tokenExpiryKey,
      value: expiry.millisecondsSinceEpoch.toString(),
    );
  }

  Future<String?> getToken() async {
    // SECURITY: Check expiry before returning token
    if (await _isTokenExpired()) {
      await _clearAuth();
      return null;
    }
    return await _secureStorage.read(key: _tokenKey);
  }

  Future<bool> _isTokenExpired() async {
    final expiryStr = await _secureStorage.read(key: _tokenExpiryKey);
    if (expiryStr == null) return true;

    try {
      final expiry = DateTime.fromMillisecondsSinceEpoch(int.parse(expiryStr));
      return DateTime.now().isAfter(expiry);
    } catch (e) {
      return true;
    }
  }

  // ========== USER DATA MANAGEMENT ==========

  Future<void> _saveUser(Map<String, dynamic> user) async {
    // SECURITY: Store user data in encrypted storage
    await _secureStorage.write(key: _userKey, value: jsonEncode(user));
  }

  Future<UserModel?> getCachedUser() async {
    final userData = await _secureStorage.read(key: _userKey);
    if (userData != null) {
      try {
        return UserModel.fromJson(jsonDecode(userData));
      } catch (e) {
        SecurityUtils.debugLog('Failed to parse cached user');
        return null;
      }
    }
    return null;
  }

  // ========== AUTH STATE ==========

  Future<void> _clearAuth() async {
    // SECURITY: Clear all sensitive data from encrypted storage
    await _secureStorage.delete(key: _tokenKey);
    await _secureStorage.delete(key: _tokenExpiryKey);
    await _secureStorage.delete(key: _userKey);

    // Also clear rate limit state on logout
    await _clearRateLimitState();
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Check if user is logged in and token is valid
  Future<bool> validateSession() async {
    // SECURITY: Check token expiry first
    if (await _isTokenExpired()) {
      return false;
    }
    final user = await getCurrentUser();
    return user != null;
  }

  /// Get remaining login attempts before lockout
  int getRemainingAttempts() {
    return _maxLoginAttempts - _loginAttempts;
  }

  /// Check if currently locked out
  bool get isLockedOut =>
      _lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!);

  // ========== UPDATE PROFILE ==========
  Future<UserModel> updateProfile({required String name, String? phone}) async {
    final sanitizedName = SecurityUtils.sanitizeName(name);
    final sanitizedPhone = phone != null
        ? SecurityUtils.sanitizePhone(phone)
        : null;

    if (!SecurityUtils.isValidName(sanitizedName)) {
      throw AuthException('Invalid name format');
    }
    if (sanitizedPhone != null &&
        sanitizedPhone.isNotEmpty &&
        !SecurityUtils.isValidPhone(sanitizedPhone)) {
      throw AuthException('Invalid phone number format');
    }

    try {
      final token = await getToken();
      if (token == null) throw AuthException('Not authenticated');

      final response = await http
          .put(
            Uri.parse('$baseUrl/user/profile'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
              'ngrok-skip-browser-warning': 'true',
            },
            body: jsonEncode({
              'name': sanitizedName,
              if (sanitizedPhone != null) 'phone': sanitizedPhone,
            }),
          )
          .timeout(_timeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final user = UserModel.fromJson(data['user']);
        await _saveUser(data['user']);
        return user;
      } else {
        throw AuthException(data['message'] ?? 'Failed to update profile');
      }
    } on SocketException {
      throw AuthException('No internet connection');
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Failed to update profile. Please try again.');
    }
  }

  // ========== CHANGE PASSWORD ==========
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    final passwordError = SecurityUtils.validatePasswordSimple(newPassword);
    if (passwordError != null) {
      throw AuthException(passwordError);
    }
    if (newPassword != newPasswordConfirmation) {
      throw AuthException('New passwords do not match');
    }

    try {
      final token = await getToken();
      if (token == null) throw AuthException('Not authenticated');

      final response = await http
          .put(
            Uri.parse('$baseUrl/user/password'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
              'ngrok-skip-browser-warning': 'true',
            },
            body: jsonEncode({
              'current_password': currentPassword,
              'password': newPassword,
              'password_confirmation': newPasswordConfirmation,
            }),
          )
          .timeout(_timeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return;
      } else {
        throw AuthException(data['message'] ?? 'Failed to change password');
      }
    } on SocketException {
      throw AuthException('No internet connection');
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Failed to change password. Please try again.');
    }
  }

  // ========== DELETE ACCOUNT ==========
  Future<void> deleteAccount({required String password}) async {
    try {
      final token = await getToken();
      if (token == null) throw AuthException('Not authenticated');

      final response = await http
          .delete(
            Uri.parse('$baseUrl/user/account'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
              'ngrok-skip-browser-warning': 'true',
            },
            body: jsonEncode({'password': password}),
          )
          .timeout(_timeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        await _clearAuth();
        return;
      } else {
        throw AuthException(data['message'] ?? 'Failed to delete account');
      }
    } on SocketException {
      throw AuthException('No internet connection');
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Failed to delete account. Please try again.');
    }
  }
}
