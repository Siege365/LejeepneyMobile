// App Theme - Centralized theming configuration
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_dimensions.dart';

/// App-wide theme configuration
class AppTheme {
  AppTheme._();

  // ========== LIGHT THEME ==========
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    colorScheme: _lightColorScheme,
    textTheme: _textTheme,
    appBarTheme: _appBarTheme,
    elevatedButtonTheme: _elevatedButtonTheme,
    outlinedButtonTheme: _outlinedButtonTheme,
    textButtonTheme: _textButtonTheme,
    inputDecorationTheme: _inputDecorationTheme,
    cardTheme: _cardTheme,
    bottomNavigationBarTheme: _bottomNavTheme,
    floatingActionButtonTheme: _fabTheme,
    snackBarTheme: _snackBarTheme,
    dialogTheme: _dialogTheme,
    dividerTheme: _dividerTheme,
  );

  // ========== COLOR SCHEME ==========
  static ColorScheme get _lightColorScheme => ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: AppColors.primary,
    secondary: AppColors.darkBlue,
    surface: AppColors.white,
    error: AppColors.error,
    onPrimary: AppColors.textPrimary,
    onSecondary: AppColors.textWhite,
    onSurface: AppColors.textPrimary,
    onError: AppColors.textWhite,
  );

  // ========== TEXT THEME ==========
  static TextTheme get _textTheme => GoogleFonts.slackeyTextTheme().copyWith(
    displayLarge: GoogleFonts.slackey(
      fontSize: 32,
      fontWeight: FontWeight.bold,
      color: AppColors.textPrimary,
    ),
    displayMedium: GoogleFonts.slackey(
      fontSize: 28,
      fontWeight: FontWeight.bold,
      color: AppColors.textPrimary,
    ),
    displaySmall: GoogleFonts.slackey(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: AppColors.textPrimary,
    ),
    headlineLarge: GoogleFonts.slackey(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ),
    headlineMedium: GoogleFonts.slackey(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ),
    headlineSmall: GoogleFonts.slackey(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ),
    titleLarge: GoogleFonts.slackey(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ),
    titleMedium: GoogleFonts.slackey(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: AppColors.textPrimary,
    ),
    titleSmall: GoogleFonts.slackey(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: AppColors.textPrimary,
    ),
    bodyLarge: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.normal,
      color: AppColors.textPrimary,
    ),
    bodyMedium: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.normal,
      color: AppColors.textPrimary,
    ),
    bodySmall: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.normal,
      color: AppColors.textSecondary,
    ),
    labelLarge: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: AppColors.textPrimary,
    ),
    labelMedium: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: AppColors.textSecondary,
    ),
    labelSmall: const TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w500,
      color: AppColors.textSecondary,
    ),
  );

  // ========== APP BAR THEME ==========
  static AppBarTheme get _appBarTheme => AppBarTheme(
    backgroundColor: AppColors.primary,
    foregroundColor: AppColors.textPrimary,
    elevation: 0,
    centerTitle: true,
    titleTextStyle: GoogleFonts.slackey(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ),
  );

  // ========== BUTTON THEMES ==========
  static ElevatedButtonThemeData get _elevatedButtonTheme =>
      ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.darkBlue,
          foregroundColor: AppColors.textWhite,
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingLarge,
            vertical: AppDimensions.paddingMedium,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
          ),
          textStyle: GoogleFonts.slackey(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  static OutlinedButtonThemeData get _outlinedButtonTheme =>
      OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.darkBlue,
          side: const BorderSide(color: AppColors.darkBlue, width: 1.5),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingLarge,
            vertical: AppDimensions.paddingMedium,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
          ),
        ),
      );

  static TextButtonThemeData get _textButtonTheme => TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: AppColors.darkBlue,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingMedium,
        vertical: AppDimensions.paddingSmall,
      ),
    ),
  );

  // ========== INPUT DECORATION ==========
  static InputDecorationTheme get _inputDecorationTheme => InputDecorationTheme(
    filled: true,
    fillColor: AppColors.white,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppDimensions.paddingMedium,
      vertical: AppDimensions.paddingMedium,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      borderSide: const BorderSide(color: AppColors.lightGray),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      borderSide: const BorderSide(color: AppColors.lightGray),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      borderSide: const BorderSide(color: AppColors.darkBlue, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      borderSide: const BorderSide(color: AppColors.error),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      borderSide: const BorderSide(color: AppColors.error, width: 2),
    ),
    hintStyle: const TextStyle(color: AppColors.gray, fontSize: 14),
    labelStyle: const TextStyle(color: AppColors.textSecondary),
    errorStyle: const TextStyle(color: AppColors.error, fontSize: 12),
  );

  // ========== CARD THEME ==========
  static CardThemeData get _cardTheme => CardThemeData(
    color: AppColors.white,
    elevation: 2,
    shadowColor: Colors.black.withValues(alpha: 0.1),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
    ),
    margin: const EdgeInsets.all(AppDimensions.paddingSmall),
  );

  // ========== BOTTOM NAV THEME ==========
  static BottomNavigationBarThemeData get _bottomNavTheme =>
      const BottomNavigationBarThemeData(
        backgroundColor: AppColors.white,
        selectedItemColor: AppColors.darkBlue,
        unselectedItemColor: AppColors.gray,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      );

  // ========== FAB THEME ==========
  static FloatingActionButtonThemeData get _fabTheme =>
      const FloatingActionButtonThemeData(
        backgroundColor: AppColors.darkBlue,
        foregroundColor: AppColors.textWhite,
        elevation: 4,
        shape: CircleBorder(),
      );

  // ========== SNACKBAR THEME ==========
  static SnackBarThemeData get _snackBarTheme => SnackBarThemeData(
    backgroundColor: AppColors.darkBlue,
    contentTextStyle: const TextStyle(color: AppColors.textWhite),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
    ),
  );

  // ========== DIALOG THEME ==========
  static DialogThemeData get _dialogTheme => DialogThemeData(
    backgroundColor: AppColors.white,
    elevation: 8,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
    ),
  );

  // ========== DIVIDER THEME ==========
  static DividerThemeData get _dividerTheme => const DividerThemeData(
    color: AppColors.lightGray,
    thickness: 1,
    space: AppDimensions.paddingMedium,
  );
}

// ========== TEXT STYLE EXTENSIONS ==========
extension AppTextStyles on TextTheme {
  TextStyle get slackeyLarge => GoogleFonts.slackey(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  TextStyle get slackeyMedium => GoogleFonts.slackey(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  TextStyle get slackeySmall => GoogleFonts.slackey(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  TextStyle get fareDisplay => GoogleFonts.slackey(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.darkBlue,
  );
}
