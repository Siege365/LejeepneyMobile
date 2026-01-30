// App Routes - Centralized navigation configuration
import 'package:flutter/material.dart';
import '../screens/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/sign_in_screen.dart';
import '../screens/main_navigation.dart';
import '../screens/fare/fare_calculator_screen.dart';
import '../screens/fare/map_fare_calculator_screen.dart';
import '../screens/search/search_screen.dart';
import '../screens/landmarks/landmarks_screen.dart';

/// Route names for type-safe navigation
class AppRoutes {
  AppRoutes._();

  // Core routes
  static const String splash = '/';
  static const String login = '/login';
  static const String signIn = '/sign-in';
  static const String home = '/home';
  static const String main = '/main';

  // Feature routes
  static const String fareCalculator = '/fare-calculator';
  static const String mapFareCalculator = '/map-fare-calculator';
  static const String search = '/search';
  static const String landmarks = '/landmarks';
  static const String landmarkDetails = '/landmark-details';
  static const String routeDetails = '/route-details';
  static const String profile = '/profile';
  static const String settings = '/settings';
}

/// Route generator for MaterialApp
class AppRouter {
  AppRouter._();

  /// Generate routes for the app
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.splash:
        return _buildRoute(const SplashScreen(), settings);

      case AppRoutes.login:
        return _buildRoute(const LoginScreen(), settings);

      case AppRoutes.signIn:
        return _buildRoute(const SignInScreen(), settings);

      case AppRoutes.main:
      case AppRoutes.home:
        final args = settings.arguments as Map<String, dynamic>?;
        return _buildRoute(
          MainNavigation(initialIndex: args?['initialIndex'] ?? 0),
          settings,
        );

      case AppRoutes.fareCalculator:
        return _buildRoute(const FareCalculatorScreen(), settings);

      case AppRoutes.mapFareCalculator:
        return _buildRoute(const MapFareCalculatorScreen(), settings);

      case AppRoutes.search:
        final args = settings.arguments as Map<String, dynamic>?;
        return _buildRoute(
          SearchScreen(
            autoSelectRouteId: args?['autoSelectRouteId'],
            autoSelectRouteIds: args?['autoSelectRouteIds'],
            landmarkLatitude: args?['landmarkLatitude'],
            landmarkLongitude: args?['landmarkLongitude'],
            landmarkName: args?['landmarkName'],
          ),
          settings,
        );

      case AppRoutes.landmarks:
        return _buildRoute(const LandmarksScreen(), settings);

      default:
        return _buildRoute(
          Scaffold(
            body: Center(child: Text('Route not found: ${settings.name}')),
          ),
          settings,
        );
    }
  }

  /// Build a MaterialPageRoute
  static MaterialPageRoute<T> _buildRoute<T>(
    Widget page,
    RouteSettings settings,
  ) {
    return MaterialPageRoute<T>(builder: (_) => page, settings: settings);
  }
}

/// Navigation service for type-safe navigation
class NavigationService {
  NavigationService._();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static NavigatorState? get navigator => navigatorKey.currentState;

  /// Navigate to a named route
  static Future<T?>? navigateTo<T>(String routeName, {Object? arguments}) {
    return navigator?.pushNamed<T>(routeName, arguments: arguments);
  }

  /// Replace current route
  static Future<T?>? replaceTo<T>(String routeName, {Object? arguments}) {
    return navigator?.pushReplacementNamed<T, void>(
      routeName,
      arguments: arguments,
    );
  }

  /// Navigate and remove all previous routes
  static Future<T?>? navigateAndRemoveAll<T>(
    String routeName, {
    Object? arguments,
  }) {
    return navigator?.pushNamedAndRemoveUntil<T>(
      routeName,
      (route) => false,
      arguments: arguments,
    );
  }

  /// Pop current route
  static void pop<T>([T? result]) {
    navigator?.pop<T>(result);
  }

  /// Pop until a specific route
  static void popUntil(String routeName) {
    navigator?.popUntil(ModalRoute.withName(routeName));
  }

  /// Check if can pop
  static bool canPop() {
    return navigator?.canPop() ?? false;
  }

  // ========== CONVENIENCE METHODS ==========

  /// Navigate to login
  static Future<void> toLogin() async {
    await navigateAndRemoveAll(AppRoutes.login);
  }

  /// Navigate to home/main
  static Future<void> toHome({int initialIndex = 0}) async {
    await navigateAndRemoveAll(
      AppRoutes.main,
      arguments: {'initialIndex': initialIndex},
    );
  }

  /// Navigate to fare calculator
  static Future<void> toFareCalculator() async {
    await navigateTo(AppRoutes.fareCalculator);
  }

  /// Navigate to map fare calculator
  static Future<dynamic> toMapFareCalculator() async {
    return await navigateTo(AppRoutes.mapFareCalculator);
  }

  /// Navigate to search with optional route selection
  static Future<void> toSearch({
    int? autoSelectRouteId,
    List<int>? autoSelectRouteIds,
    double? landmarkLatitude,
    double? landmarkLongitude,
    String? landmarkName,
  }) async {
    await navigateTo(
      AppRoutes.search,
      arguments: {
        'autoSelectRouteId': autoSelectRouteId,
        'autoSelectRouteIds': autoSelectRouteIds,
        'landmarkLatitude': landmarkLatitude,
        'landmarkLongitude': landmarkLongitude,
        'landmarkName': landmarkName,
      },
    );
  }

  /// Navigate to landmarks
  static Future<void> toLandmarks() async {
    await navigateTo(AppRoutes.landmarks);
  }
}
