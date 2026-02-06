import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'constants/app_routes.dart';
import 'constants/app_strings.dart';
import 'constants/app_theme.dart';
import 'providers/app_providers.dart';
import 'services/recent_activity_service_v2.dart';
import 'services/ticket_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services in background (non-blocking)
  RecentActivityServiceV2.initialize().catchError((error) {
    debugPrint('Failed to initialize RecentActivityService: $error');
  });

  TicketNotificationService.instance.init().catchError((error) {
    debugPrint('Failed to initialize TicketNotificationService: $error');
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AppProviderScope(
      child: MaterialApp(
        title: AppStrings.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        navigatorKey: NavigationService.navigatorKey,
        onGenerateRoute: AppRouter.onGenerateRoute,
        initialRoute: AppRoutes.splash,
      ),
    );
  }
}
