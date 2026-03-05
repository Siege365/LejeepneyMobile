import 'package:shared_preferences/shared_preferences.dart';

/// Manages per-screen tutorial state using SharedPreferences.
/// Each screen has its own key so tutorials can be shown/reset independently.
class FeatureTutorialService {
  FeatureTutorialService._();
  static final FeatureTutorialService instance = FeatureTutorialService._();

  static const String _prefix = 'tutorial_seen_';

  // Screen keys
  static const String searchScreen = 'search';
  static const String fareCalculator = 'fare_calculator';
  static const String landmarks = 'landmarks';

  // Active tutorial state - prevents tab switching during tutorials
  bool _isTutorialActive = false;
  bool get isTutorialActive => _isTutorialActive;

  void setTutorialActive(bool active) {
    _isTutorialActive = active;
  }

  /// Check whether the tutorial for [screenKey] has been seen.
  Future<bool> hasSeenTutorial(String screenKey) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_prefix$screenKey') ?? false;
  }

  /// Mark the tutorial for [screenKey] as seen.
  Future<void> markSeen(String screenKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefix$screenKey', true);
  }

  /// Reset tutorial for a single screen.
  Future<void> resetTutorial(String screenKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$screenKey');
  }

  /// Reset ALL per-screen tutorials (and the main app tutorial).
  /// Called from Settings → "Reset All Tutorials" and also on logout.
  Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    // Remove the main app tutorial key
    await prefs.remove('has_seen_tutorial');
    // Remove all per-screen tutorial keys
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix)).toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}
