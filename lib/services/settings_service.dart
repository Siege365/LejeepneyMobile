import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized settings service for the entire app.
/// Manages all user preferences with persistence and change notification.
class SettingsService extends ChangeNotifier {
  // Singleton for global access
  static SettingsService? _instance;
  static SettingsService get instance => _instance ??= SettingsService._();

  SettingsService._() {
    _loadAll();
  }

  // For provider usage
  factory SettingsService() => instance;

  // ─── Keys ──────────────────────────────────────────────
  static const _keyPushNotifications = 'push_notifications';
  static const _keySupportTicketUpdates = 'support_ticket_updates';
  static const _keySoundEnabled = 'sound_enabled';
  static const _keyVibration = 'vibration';
  static const _keyLocationServices = 'location_services';
  static const _keyLanguage = 'language';
  static const _keyDistanceUnit = 'distance_unit';

  // ─── State ─────────────────────────────────────────────
  bool _pushNotifications = true;
  bool _supportTicketUpdates = true;
  bool _soundEnabled = true;
  bool _vibration = true;
  bool _locationServices = true;
  String _language = 'English';
  String _distanceUnit = 'Kilometers';
  bool _isLoaded = false;

  // ─── Getters ───────────────────────────────────────────
  bool get pushNotifications => _pushNotifications;
  bool get supportTicketUpdates => _supportTicketUpdates;
  bool get soundEnabled => _soundEnabled;
  bool get vibration => _vibration;
  bool get locationServices => _locationServices;
  String get language => _language;
  String get distanceUnit => _distanceUnit;
  bool get isLoaded => _isLoaded;

  /// Whether to use miles instead of kilometers
  bool get useMiles => _distanceUnit == 'Miles';

  // ─── Load ──────────────────────────────────────────────
  Future<void> _loadAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _pushNotifications = prefs.getBool(_keyPushNotifications) ?? true;
      _supportTicketUpdates = prefs.getBool(_keySupportTicketUpdates) ?? true;
      _soundEnabled = prefs.getBool(_keySoundEnabled) ?? true;
      _vibration = prefs.getBool(_keyVibration) ?? true;
      _locationServices = prefs.getBool(_keyLocationServices) ?? true;
      _language = prefs.getString(_keyLanguage) ?? 'English';
      _distanceUnit = prefs.getString(_keyDistanceUnit) ?? 'Kilometers';
      _isLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[SettingsService] Error loading settings: $e');
      _isLoaded = true;
    }
  }

  // ─── Setters (persist + notify) ────────────────────────
  Future<void> setPushNotifications(bool value) async {
    _pushNotifications = value;
    await _saveBool(_keyPushNotifications, value);
    notifyListeners();
  }

  Future<void> setSupportTicketUpdates(bool value) async {
    _supportTicketUpdates = value;
    await _saveBool(_keySupportTicketUpdates, value);
    notifyListeners();
  }

  Future<void> setSoundEnabled(bool value) async {
    _soundEnabled = value;
    await _saveBool(_keySoundEnabled, value);
    notifyListeners();
  }

  Future<void> setVibration(bool value) async {
    _vibration = value;
    await _saveBool(_keyVibration, value);
    notifyListeners();
  }

  Future<void> setLocationServices(bool value) async {
    _locationServices = value;
    await _saveBool(_keyLocationServices, value);
    notifyListeners();
  }

  Future<void> setLanguage(String value) async {
    _language = value;
    await _saveString(_keyLanguage, value);
    notifyListeners();
  }

  Future<void> setDistanceUnit(String value) async {
    _distanceUnit = value;
    await _saveString(_keyDistanceUnit, value);
    notifyListeners();
  }

  // ─── Distance Formatting ───────────────────────────────

  /// Format a distance in kilometers to the user's preferred unit.
  /// [distanceKm] is always in kilometers (from the API/GPS).
  String formatDistance(double distanceKm) {
    if (useMiles) {
      final miles = distanceKm * 0.621371;
      return '${miles.toStringAsFixed(1)} mi';
    }
    return '${distanceKm.toStringAsFixed(1)} km';
  }

  // ─── Notification Helpers ──────────────────────────────

  /// Whether ticket-related notifications should be shown
  bool get shouldShowTicketNotifications =>
      _pushNotifications && _supportTicketUpdates;

  /// Trigger haptic feedback if vibration is enabled
  void triggerVibration() {
    if (_vibration) {
      HapticFeedback.mediumImpact();
    }
  }

  /// Trigger notification feedback (vibration + sound indication)
  void triggerNotificationFeedback() {
    if (_vibration) {
      HapticFeedback.heavyImpact();
    }
    // Sound is handled by system notification channel;
    // this flag can be checked by callers for custom sounds
  }

  // ─── Private Helpers ───────────────────────────────────
  Future<void> _saveBool(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (e) {
      debugPrint('[SettingsService] Error saving $key: $e');
    }
  }

  Future<void> _saveString(String key, String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } catch (e) {
      debugPrint('[SettingsService] Error saving $key: $e');
    }
  }

  /// Clear all cached data (preserves settings)
  Future<void> clearCache() async {
    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      final prefs = await SharedPreferences.getInstance();
      // Save current settings
      final saved = <String, dynamic>{
        _keyPushNotifications: _pushNotifications,
        _keySupportTicketUpdates: _supportTicketUpdates,
        _keySoundEnabled: _soundEnabled,
        _keyVibration: _vibration,
        _keyLocationServices: _locationServices,
        _keyLanguage: _language,
        _keyDistanceUnit: _distanceUnit,
      };

      await prefs.clear();

      // Restore settings
      for (final entry in saved.entries) {
        if (entry.value is bool) {
          await prefs.setBool(entry.key, entry.value as bool);
        } else if (entry.value is String) {
          await prefs.setString(entry.key, entry.value as String);
        }
      }
    } catch (e) {
      debugPrint('[SettingsService] Error clearing cache: $e');
    }
  }
}
