// App Providers
// Centralized Provider configuration for the app

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import '../repositories/repositories.dart';
import '../controllers/controllers.dart';
import '../services/location_service.dart';

/// Creates all app-level providers
List<SingleChildWidget> get appProviders => [
  // Core Services (singletons)
  Provider<LocationService>(create: (_) => LocationService()),

  // Repositories (ChangeNotifierProvider for reactive updates)
  ChangeNotifierProvider<AuthRepository>(create: (_) => AuthRepository()),
  ChangeNotifierProvider<RouteRepository>(create: (_) => RouteRepository()),
  ChangeNotifierProvider<LandmarkRepository>(
    create: (_) => LandmarkRepository(),
  ),

  // Controllers (dependent on repositories)
  ChangeNotifierProxyProvider<RouteRepository, FareCalculatorController>(
    create: (_) => FareCalculatorController(),
    update: (_, routeRepo, controller) {
      // Controller can access route data through repository
      return controller ?? FareCalculatorController();
    },
  ),
];

/// Wraps the app with all providers
class AppProviderScope extends StatelessWidget {
  final Widget child;

  const AppProviderScope({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(providers: appProviders, child: child);
  }
}

/// Extension for easy context access to repositories
extension RepositoryContext on BuildContext {
  /// Get AuthRepository
  AuthRepository get authRepository => read<AuthRepository>();
  AuthRepository watchAuth() => watch<AuthRepository>();

  /// Get RouteRepository
  RouteRepository get routeRepository => read<RouteRepository>();
  RouteRepository watchRoutes() => watch<RouteRepository>();

  /// Get LandmarkRepository
  LandmarkRepository get landmarkRepository => read<LandmarkRepository>();
  LandmarkRepository watchLandmarks() => watch<LandmarkRepository>();

  /// Get LocationService
  LocationService get locationService => read<LocationService>();

  /// Get FareCalculatorController
  FareCalculatorController get fareCalculator =>
      read<FareCalculatorController>();
  FareCalculatorController watchFareCalculator() =>
      watch<FareCalculatorController>();
}

/// Mixin for screens that need common repository access
mixin RepositoryAccessMixin<T extends StatefulWidget> on State<T> {
  AuthRepository get authRepository => context.authRepository;
  RouteRepository get routeRepository => context.routeRepository;
  LandmarkRepository get landmarkRepository => context.landmarkRepository;
  LocationService get locationService => context.locationService;
}
