import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../services/feature_tutorial_service.dart';

/// A tutorial step definition for per-screen tutorials.
class TutorialStep {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const TutorialStep({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
}

/// Reusable per-screen tutorial overlay.
///
/// Shows a PageView walkthrough specific to each screen.
/// Auto-marks the tutorial as seen when user finishes or skips.
///
/// Usage:
/// ```dart
/// if (_showTutorial)
///   ScreenTutorialOverlay(
///     screenKey: FeatureTutorialService.searchScreen,
///     steps: [...],
///     onComplete: () => setState(() => _showTutorial = false),
///   ),
/// ```
class ScreenTutorialOverlay extends StatefulWidget {
  final String screenKey;
  final List<TutorialStep> steps;
  final VoidCallback onComplete;

  const ScreenTutorialOverlay({
    super.key,
    required this.screenKey,
    required this.steps,
    required this.onComplete,
  });

  @override
  State<ScreenTutorialOverlay> createState() => _ScreenTutorialOverlayState();
}

class _ScreenTutorialOverlayState extends State<ScreenTutorialOverlay>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    // Block tab switching while tutorial is active
    FeatureTutorialService.instance.setTutorialActive(true);
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < widget.steps.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  void _finish() async {
    // Re-enable tab switching
    FeatureTutorialService.instance.setTutorialActive(false);
    await FeatureTutorialService.instance.markSeen(widget.screenKey);
    await _fadeController.reverse();
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Material(
        color: Colors.black.withValues(alpha: 0.88),
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
                  itemCount: widget.steps.length,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemBuilder: (context, index) {
                    final step = widget.steps[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Icon circle
                          Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: step.color.withValues(alpha: 0.2),
                              border: Border.all(
                                color: step.color.withValues(alpha: 0.5),
                                width: 2,
                              ),
                            ),
                            child: Icon(step.icon, size: 50, color: step.color),
                          ),
                          const SizedBox(height: 36),
                          // Title
                          Text(
                            step.title,
                            style: GoogleFonts.slackey(
                              fontSize: 22,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 14),
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
                        widget.steps.length,
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
                    const SizedBox(height: 28),
                    // Next / Got it button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
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
                          _currentPage == widget.steps.length - 1
                              ? 'Got It!'
                              : 'Next',
                          style: GoogleFonts.slackey(fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
