import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'constants/app_routes.dart';
import 'constants/app_strings.dart';
import 'constants/app_theme.dart';
import 'providers/app_providers.dart';
import 'services/recent_activity_service_v2.dart';
import 'services/ticket_notification_service.dart';
import 'services/settings_service.dart';
import 'services/fare_settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services in background (non-blocking)
  RecentActivityServiceV2.initialize().catchError((error) {
    debugPrint('Failed to initialize RecentActivityService: $error');
  });

  TicketNotificationService.instance.init().catchError((error) {
    debugPrint('Failed to initialize TicketNotificationService: $error');
  });

  // Fetch admin fare settings (base_fare, fare_per_km) from API
  FareSettingsService.instance.initialize().catchError((error) {
    debugPrint('Failed to initialize FareSettingsService: $error');
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AppProviderScope(
      // Consumer rebuilds the entire app when language changes,
      // which causes all screens using LocalizationService to update.
      // We keep Flutter's locale as English since fil/ceb aren't
      // supported by MaterialLocalizations.
      child: Consumer<SettingsService>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: AppStrings.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            navigatorKey: NavigationService.navigatorKey,
            onGenerateRoute: AppRouter.onGenerateRoute,
            initialRoute: AppRoutes.splash,
          );
        },
      ),
    );
  }
}
