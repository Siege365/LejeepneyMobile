import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../utils/page_transitions.dart';
import '../../widgets/travel_history_item.dart';
import '../main_navigation.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),

              // Welcome Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome to Lejeepney',
                      style: GoogleFonts.slackey(
                        fontSize: 27.5,
                        color: AppColors.textPrimary.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your jeepney companion in Davao City',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimary.withValues(alpha: 0.7),
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
                    ScaleFadeRoute(page: const MainNavigation(initialIndex: 1)),
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
                            color: AppColors.darkBlue.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Tap to search',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.darkBlue.withValues(alpha: 0.7),
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

              // Recent Activity Section
              Container(
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
                            color: AppColors.primary.withValues(alpha: 0.2),
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
                    const RecentActivityItem(
                      date: 'July 18, 2024',
                      route: 'Bankerohan to Maga...',
                    ),
                    const SizedBox(height: 12),
                    const RecentActivityItem(
                      date: 'July 20, 2024',
                      route: 'Bankerohan to Calinan',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 100), // Space for bottom nav
            ],
          ),
        ),
      ),
    );
  }
}
