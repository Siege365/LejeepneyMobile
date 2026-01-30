// Auth Repository
// Manages authentication state with Provider integration

import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import 'base_repository.dart';

/// Authentication state enum
enum AuthState { initial, loading, authenticated, unauthenticated, error }

class AuthRepository extends ChangeNotifier {
  final AuthService _authService;

  // State
  AuthState _state = AuthState.initial;
  UserModel? _user;
  String? _error;
  bool _isInitialized = false;

  AuthRepository({AuthService? authService})
    : _authService = authService ?? AuthService();

  // Getters
  AuthState get state => _state;
  UserModel? get user => _user;
  String? get error => _error;
  bool get isAuthenticated =>
      _state == AuthState.authenticated && _user != null;
  bool get isLoading => _state == AuthState.loading;
  bool get isInitialized => _isInitialized;

  /// Initialize - check for existing session
  Future<void> initialize() async {
    if (_isInitialized) return;

    _state = AuthState.loading;
    notifyListeners();

    try {
      final isLoggedIn = await _authService.isLoggedIn();

      if (isLoggedIn) {
        _user = await _authService.getCurrentUser();
        _state = AuthState.authenticated;
      } else {
        _state = AuthState.unauthenticated;
      }
    } catch (e) {
      _state = AuthState.unauthenticated;
      _error = e.toString();
    }

    _isInitialized = true;
    notifyListeners();
  }

  /// Login with email and password
  Future<Result<UserModel>> login({
    required String email,
    required String password,
  }) async {
    _state = AuthState.loading;
    _error = null;
    notifyListeners();

    try {
      final user = await _authService.login(email: email, password: password);

      _user = user;
      _state = AuthState.authenticated;
      notifyListeners();

      return Result.success(user);
    } on AuthException catch (e) {
      _state = AuthState.error;
      _error = e.message;
      notifyListeners();
      return Result.failure(e.message);
    } catch (e) {
      _state = AuthState.error;
      _error = 'An unexpected error occurred';
      notifyListeners();
      return Result.failure(e.toString());
    }
  }

  /// Register new user
  Future<Result<UserModel>> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    String? phone,
  }) async {
    _state = AuthState.loading;
    _error = null;
    notifyListeners();

    try {
      final user = await _authService.register(
        name: name,
        email: email,
        password: password,
        passwordConfirmation: passwordConfirmation,
        phone: phone,
      );

      _user = user;
      _state = AuthState.authenticated;
      notifyListeners();

      return Result.success(user);
    } on AuthException catch (e) {
      _state = AuthState.error;
      _error = e.message;
      notifyListeners();
      return Result.failure(e.message);
    } catch (e) {
      _state = AuthState.error;
      _error = 'Registration failed';
      notifyListeners();
      return Result.failure(e.toString());
    }
  }

  /// Logout
  Future<void> logout() async {
    _state = AuthState.loading;
    notifyListeners();

    try {
      await _authService.logout();
    } catch (e) {
      debugPrint('Logout error: $e');
    }

    _user = null;
    _state = AuthState.unauthenticated;
    _error = null;
    notifyListeners();
  }

  /// Refresh user data from API
  Future<Result<UserModel>> refreshUser() async {
    try {
      final user = await _authService.getCurrentUser();
      if (user != null) {
        _user = user;
        notifyListeners();
        return Result.success(user);
      }
      return Result.failure('User not found');
    } catch (e) {
      return Result.failure(e.toString());
    }
  }

  // TODO: Implement updateProfile when AuthService supports it
  // Future<Result<UserModel>> updateProfile({String? name, String? phone}) async { }

  // TODO: Implement changePassword when AuthService supports it
  // Future<Result<void>> changePassword({ ... }) async { }

  /// Clear error state
  void clearError() {
    _error = null;
    if (_state == AuthState.error) {
      _state = _user != null
          ? AuthState.authenticated
          : AuthState.unauthenticated;
    }
    notifyListeners();
  }
}
