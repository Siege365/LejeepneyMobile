import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'home/home_screen.dart';
import 'search/search_screen.dart';
import 'fare/fare_calculator_screen.dart';
import 'landmarks/landmarks_screen.dart';
import 'profile/profile_screen.dart';

class MainNavigation extends StatefulWidget {
  final int initialIndex;
  final int? autoSelectRouteId;

  const MainNavigation({
    super.key,
    this.initialIndex = 0,
    this.autoSelectRouteId,
  });

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  late int _currentIndex;
  int? _autoSelectRouteId;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _autoSelectRouteId = widget.autoSelectRouteId;
  }

  List<Widget> get _screens => [
    const HomeScreen(key: ValueKey('home')),
    SearchScreen(
      key: const ValueKey('search'),
      autoSelectRouteId: _autoSelectRouteId,
      onAutoSelectionComplete: () {
        // Clear the route ID after auto-selection to prevent it from happening again
        if (mounted) {
          setState(() {
            _autoSelectRouteId = null;
          });
        }
      },
    ),
    const FareCalculatorScreen(key: ValueKey('fare')),
    const LandmarksScreen(key: ValueKey('landmarks')),
    const ProfileScreen(key: ValueKey('profile')),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0.05, 0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(parent: animation, curve: Curves.easeInOut),
                  ),
              child: child,
            ),
          );
        },
        child: _screens[_currentIndex],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildNavItem(0, Icons.home, 'Home'),
                _buildNavItem(1, Icons.search, 'Search'),
                _buildCenterNavItem(),
                _buildNavItem(3, Icons.location_on, 'Landmarks'),
                _buildNavItem(4, Icons.person_outline, 'Profile'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentIndex = index),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.darkBlue : AppColors.gray,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.darkBlue : AppColors.gray,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterNavItem() {
    final isSelected = _currentIndex == 2;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentIndex = 2),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: isSelected
                  ? [AppColors.darkBlue, const Color(0xFF1E88E5)]
                  : [const Color(0xFF7B68EE), const Color(0xFF9370DB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.darkBlue.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.directions_bus,
            color: AppColors.white,
            size: 28,
          ),
        ),
      ),
    );
  }
}
