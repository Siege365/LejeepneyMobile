import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/auth_service.dart';
import '../utils/page_transitions.dart';
import 'auth/login_screen.dart';
import 'main_navigation.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    // Wait for splash screen to display
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Check if user has a valid session
    final isLoggedIn = await _authService.isLoggedIn();

    if (!mounted) return;

    if (isLoggedIn) {
      // User is logged in - validate session with server
      final user = await _authService.getCurrentUser();

      if (!mounted) return;

      if (user != null) {
        // Valid session - go to home
        Navigator.pushReplacement(
          context,
          FadeRoute(page: const MainNavigation()),
        );
      } else {
        // Invalid token - go to login
        Navigator.pushReplacement(
          context,
          FadeRoute(page: const LoginScreen()),
        );
      }
    } else {
      // Not logged in - go to login
      Navigator.pushReplacement(context, FadeRoute(page: const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Jeepney Logo
              Image.asset(
                'assets/images/LogoSplashScreen.png',
                width: 280,
                height: 280,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 24),
              // Loading indicator
              const CircularProgressIndicator(
                color: AppColors.white,
                strokeWidth: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
