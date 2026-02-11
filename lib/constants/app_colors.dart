// App Colors - Define all your colors here
import 'package:flutter/material.dart';

class AppColors {
  // Main brand colors (LeJeepney)
  static const Color primary = Color(
    0xFFEBAF3E,
  ); // Orange/Golden - main background
  static const Color white = Color(0xFFFFFFFF); // White
  static const Color darkBlue = Color(0xFF0C4E94); // Dark Blue

  // Button colors
  static const Color googleBlue = Color(0xFF4285F4);
  static const Color facebookBlue = Color(0xFF1877F2);
  static const Color gray = Color(0xFF6B6B6B);
  static const Color lightGray = Color(0xFFE0E0E0);

  // Text colors
  static const Color textPrimary = Color(0xFF000000);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textWhite = Color(0xFFFFFFFF);

  // Background colors
  static const Color background = Color(0xFFFFFFFF);
  static const Color backgroundDark = Color(0xFF121212);

  // Status colors
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFB00020);
  static const Color warning = Color(0xFFFFA000);
  static const Color info = Color(0xFF2196F3);

  // Accent colors
  static const Color teal = Color(0xFF4A90A4); // Support & secondary accent

  // Gradients
  static const LinearGradient blueGradient = LinearGradient(
    colors: [Color(0xFF1E88E5), Color(0xFF0C4E94)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}
