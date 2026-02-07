import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/app_colors.dart';

/// Full-screen tutorial overlay that introduces app features.
/// Auto-plays on first launch; can be replayed from the help button.
class TutorialOverlay extends StatefulWidget {
  final VoidCallback onComplete;

  const TutorialOverlay({super.key, required this.onComplete});

  /// SharedPreferences key to track whether tutorial has been shown
  static const String _hasSeenTutorialKey = 'has_seen_tutorial';

  /// Check if the user has already seen the tutorial
  static Future<bool> hasSeenTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasSeenTutorialKey) ?? false;
  }

  /// Mark the tutorial as seen
  static Future<void> markAsSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasSeenTutorialKey, true);
  }

  /// Reset tutorial so it plays again on next launch
  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_hasSeenTutorialKey);
  }

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const List<_TutorialStep> _steps = [
    _TutorialStep(
      icon: Icons.map_outlined,
      title: 'Explore Routes',
      description:
          'Search and view jeepney routes across Davao City. Tap on the map to find the best route for your destination.',
      color: AppColors.darkBlue,
    ),
    _TutorialStep(
      icon: Icons.calculate_outlined,
      title: 'Fare Calculator',
      description:
          'Calculate your jeepney fare based on distance. Select your start and end points to get an accurate fare estimate.',
      color: Color(0xFF4CAF50),
    ),
    _TutorialStep(
      icon: Icons.place_outlined,
      title: 'Discover Landmarks',
      description:
          'Browse nearby landmarks, view their gallery, and get directions. Swipe through photos and tap Get Directions.',
      color: Color(0xFFE67E22),
    ),
    _TutorialStep(
      icon: Icons.support_agent_outlined,
      title: 'Support Tickets',
      description:
          'Need help? Create support tickets, chat with our team, and track your issues in real time.',
      color: AppColors.teal,
    ),
    _TutorialStep(
      icon: Icons.person_outline,
      title: 'Your Profile',
      description:
          'Manage your account settings, view recent activity, and customise notifications from your profile.',
      color: Color(0xFF9C27B0),
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _steps.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  void _finish() async {
    await TutorialOverlay.markAsSeen();
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.85),
      child: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton(
                  onPressed: _finish,
                  child: Text(
                    'Skip',
                    style: GoogleFonts.slackey(
                      fontSize: 14,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ),

            // Page content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _steps.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) {
                  final step = _steps[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Icon circle
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: step.color.withValues(alpha: 0.2),
                            border: Border.all(
                              color: step.color.withValues(alpha: 0.5),
                              width: 2,
                            ),
                          ),
                          child: Icon(step.icon, size: 56, color: step.color),
                        ),
                        const SizedBox(height: 40),
                        // Title
                        Text(
                          step.title,
                          style: GoogleFonts.slackey(
                            fontSize: 26,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        // Description
                        Text(
                          step.description,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.white70,
                            height: 1.6,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Page indicators + Next button
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
              child: Column(
                children: [
                  // Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _steps.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == i ? 28 : 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _currentPage == i
                              ? AppColors.primary
                              : Colors.white24,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Next / Get Started button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.textPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        _currentPage == _steps.length - 1
                            ? 'Get Started'
                            : 'Next',
                        style: GoogleFonts.slackey(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Data class for a single tutorial step
class _TutorialStep {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const _TutorialStep({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
}
