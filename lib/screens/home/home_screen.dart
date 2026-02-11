import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../utils/page_transitions.dart';
import '../../widgets/travel_history_item.dart';
import '../../widgets/common/tutorial_overlay.dart';
import '../main_navigation.dart';
import '../profile/recent_activity_screen.dart';
import '../../models/recent_activity_model.dart';
import '../../services/recent_activity_service_v2.dart';
import '../../services/auth_service.dart';
import '../../services/settings_service.dart';
import '../../services/localization_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService = AuthService();
  List<RecentActivityModel> _recentActivities = [];
  bool _isLoading = false;
  bool _showTutorial = false;

  @override
  void initState() {
    super.initState();
    _loadRecentActivities();
    _checkFirstTimeTutorial();
  }

  Future<void> _checkFirstTimeTutorial() async {
    final seen = await TutorialOverlay.hasSeenTutorial();
    if (!seen && mounted) {
      setState(() => _showTutorial = true);
    }
  }

  void _showTutorialOverlay() {
    setState(() => _showTutorial = true);
  }

  Future<void> _loadRecentActivities() async {
    setState(() => _isLoading = true);

    // Check if user is authenticated
    final isLoggedIn = await _authService.isLoggedIn();

    if (!isLoggedIn) {
      // Clear activities if user is not logged in (guest mode)
      debugPrint('[HomeScreen] User not logged in, clearing activities');
      await RecentActivityServiceV2.clearAll();
      setState(() {
        _recentActivities = [];
        _isLoading = false;
      });
      return;
    }

    // Load recent activities (limit to 3 for home screen)
    final activities = await RecentActivityServiceV2.getRecentActivities(
      limit: 3,
    );

    debugPrint('[HomeScreen] Loaded ${activities.length} activities');

    setState(() {
      _recentActivities = activities;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.primary,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),

                  // Welcome Header with Help Button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Consumer<SettingsService>(
                            builder: (context, settings, child) {
                              final lang = settings.language;
                              final t = (String key) =>
                                  LocalizationService.translate(key, lang);
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t('welcome_message'),
                                    style: GoogleFonts.slackey(
                                      fontSize: 27.5,
                                      color: AppColors.textPrimary.withValues(
                                        alpha: 0.8,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Your jeepney companion in Davao City',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textPrimary.withValues(
                                        alpha: 0.7,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        // Help / Tutorial button
                        GestureDetector(
                          onTap: _showTutorialOverlay,
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppColors.darkBlue,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.darkBlue.withValues(
                                    alpha: 0.3,
                                  ),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.help_outline,
                              color: AppColors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Map Card - Look for your location (Clickable)
                  InkWell(
                    onTap: () {
                      // Navigate to MainNavigation with Search tab selected
                      Navigator.pushReplacement(
                        context,
                        ScaleFadeRoute(
                          page: const MainNavigation(initialIndex: 1),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.darkBlue.withValues(alpha: 0.1),
                            blurRadius: 15,
                            offset: const Offset(0, 6),
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Image.asset(
                              'assets/images/MapLogoHomepage.png',
                              width: 200,
                              height: 200,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 14),
                          // Title
                          Text(
                            'Look for your location',
                            style: GoogleFonts.slackey(
                              fontSize: 22,
                              color: AppColors.textPrimary,
                              height: 1.3,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.touch_app,
                                size: 16,
                                color: AppColors.darkBlue.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Tap to search',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.darkBlue.withValues(
                                    alpha: 0.7,
                                  ),
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Recent Activity Section (Clickable)
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        ScaleFadeRoute(page: const RecentActivityScreen()),
                      );
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.darkBlue.withValues(alpha: 0.1),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title with icon
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.2,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.history,
                                  color: AppColors.darkBlue,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Recent Activity',
                                style: GoogleFonts.slackey(
                                  fontSize: 20,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Recent Activity Items
                          if (_isLoading)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(20),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          else if (_recentActivities.isEmpty)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Text(
                                  'No recent activity yet',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ),
                            )
                          else
                            ..._recentActivities.map((activity) {
                              return Column(
                                children: [
                                  RecentActivityItem(
                                    title: _getActivityTitle(activity),
                                    route: activity.subtitle ?? '',
                                    activityType: activity.activityType,
                                  ),
                                  if (activity != _recentActivities.last)
                                    const SizedBox(height: 12),
                                ],
                              );
                            }),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 100), // Space for bottom nav
                ],
              ),
            ),
          ),
        ),
        // Tutorial overlay
        if (_showTutorial)
          TutorialOverlay(
            onComplete: () => setState(() => _showTutorial = false),
          ),
      ],
    );
  }

  String _getActivityTitle(RecentActivityModel activity) {
    switch (activity.activityType) {
      case 'route_calculated':
        return 'Route Calculated';
      case 'fare_calculated':
        return 'Fare Calculated';
      case 'location_search':
        return 'Location Searched';
      case 'route_saved':
        return 'Route Saved';
      case 'support_ticket':
      case 'customer_service':
        return 'Support Ticket';
      default:
        return activity.title;
    }
  }
}
