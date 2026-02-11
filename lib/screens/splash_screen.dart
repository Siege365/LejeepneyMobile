import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../repositories/repositories.dart';
import '../services/app_data_preloader.dart';
import '../utils/page_transitions.dart';
import 'auth/login_screen.dart';
import 'main_navigation.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeAndNavigate();
  }

  Future<void> _initializeAndNavigate() async {
    // Pre-load all data in parallel while splash is showing
    final routeRepo = context.read<RouteRepository>();
    final landmarkRepo = context.read<LandmarkRepository>();
    final authRepo = context.read<AuthRepository>();

    await AppDataPreloader.instance.initialize(
      routeRepository: routeRepo,
      landmarkRepository: landmarkRepo,
      authRepository: authRepo,
    );

    if (!mounted) return;

    // Navigate based on auth state (already loaded by preloader)
    if (authRepo.isAuthenticated) {
      Navigator.pushReplacement(
        context,
        FadeRoute(page: const MainNavigation()),
      );
    } else {
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
                'assets/images/LeJeepneyFinal.png',
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
