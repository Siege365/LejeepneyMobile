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
  final double? landmarkLatitude;
  final double? landmarkLongitude;
  final String? landmarkName;

  const MainNavigation({
    super.key,
    this.initialIndex = 0,
    this.autoSelectRouteId,
    this.landmarkLatitude,
    this.landmarkLongitude,
    this.landmarkName,
  });

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  late int _currentIndex;
  int? _autoSelectRouteId;
  double? _landmarkLatitude;
  double? _landmarkLongitude;
  String? _landmarkName;
  int _searchScreenKey = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _autoSelectRouteId = widget.autoSelectRouteId;
    _landmarkLatitude = widget.landmarkLatitude;
    _landmarkLongitude = widget.landmarkLongitude;
    _landmarkName = widget.landmarkName;

    // Increment key only if landmark data is provided
    if (_landmarkLatitude != null || _autoSelectRouteId != null) {
      _searchScreenKey++;
    }
  }

  List<Widget> get _screens => [
    const HomeScreen(key: ValueKey('home')),
    SearchScreen(
      key: ValueKey('search_$_searchScreenKey'),
      autoSelectRouteId: _autoSelectRouteId,
      landmarkLatitude: _landmarkLatitude,
      landmarkLongitude: _landmarkLongitude,
      landmarkName: _landmarkName,
      onAutoSelectionComplete: () {
        // Clear the route ID and landmark data after auto-selection
        // Don't increment key here - keep SearchScreen instance alive
        if (mounted) {
          setState(() {
            _autoSelectRouteId = null;
            _landmarkLatitude = null;
            _landmarkLongitude = null;
            _landmarkName = null;
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
