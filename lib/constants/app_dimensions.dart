// App Dimensions - Centralized spacing, sizing, and layout constants
import 'package:flutter/material.dart';

/// All dimension constants for consistent spacing and sizing
class AppDimensions {
  AppDimensions._();

  // ========== PADDING & SPACING ==========
  static const double paddingXSmall = 4.0;
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  static const double paddingXLarge = 32.0;
  static const double paddingXXLarge = 48.0;

  // ========== MARGINS ==========
  static const double marginSmall = 8.0;
  static const double marginMedium = 16.0;
  static const double marginLarge = 24.0;

  // ========== BORDER RADIUS ==========
  static const double radiusXSmall = 4.0;
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXLarge = 20.0;
  static const double radiusRound = 25.0;
  static const double radiusCircle = 100.0;

  // ========== ICON SIZES ==========
  static const double iconXSmall = 12.0;
  static const double iconSmall = 16.0;
  static const double iconMedium = 24.0;
  static const double iconLarge = 32.0;
  static const double iconXLarge = 48.0;
  static const double iconXXLarge = 64.0;

  // ========== BUTTON SIZES ==========
  static const double buttonHeight = 48.0;
  static const double buttonHeightSmall = 36.0;
  static const double buttonHeightLarge = 56.0;
  static const double buttonMinWidth = 120.0;

  // ========== CARD DIMENSIONS ==========
  static const double cardElevation = 2.0;
  static const double cardElevationHigh = 4.0;
  static const double cardMinHeight = 80.0;

  // ========== INPUT FIELDS ==========
  static const double inputHeight = 48.0;
  static const double inputHeightLarge = 56.0;
  static const double textFieldMaxWidth = 400.0;

  // ========== MAP DIMENSIONS ==========
  static const double markerSizeSmall = 30.0;
  static const double markerSizeMedium = 40.0;
  static const double markerSizeLarge = 50.0;
  static const double mapDefaultZoom = 14.0;
  static const double mapMinZoom = 10.0;
  static const double mapMaxZoom = 18.0;

  // ========== AVATAR & IMAGE SIZES ==========
  static const double avatarSmall = 32.0;
  static const double avatarMedium = 48.0;
  static const double avatarLarge = 64.0;
  static const double avatarXLarge = 96.0;
  static const double thumbnailSize = 80.0;

  // ========== BOTTOM SHEET ==========
  static const double bottomSheetRadius = 20.0;
  static const double bottomSheetHandleWidth = 40.0;
  static const double bottomSheetHandleHeight = 4.0;
  static const double bottomSheetMinHeight = 200.0;

  // ========== APP BAR ==========
  static const double appBarHeight = 56.0;
  static const double appBarElevation = 0.0;

  // ========== DIVIDER ==========
  static const double dividerThickness = 1.0;
  static const double dividerThicknessBold = 2.0;

  // ========== ANIMATION DURATIONS (milliseconds) ==========
  static const int animationFast = 150;
  static const int animationNormal = 300;
  static const int animationSlow = 500;

  // ========== BREAKPOINTS ==========
  static const double mobileBreakpoint = 600.0;
  static const double tabletBreakpoint = 900.0;
  static const double desktopBreakpoint = 1200.0;
}

// ========== EDGE INSETS SHORTCUTS ==========
class AppPadding {
  AppPadding._();

  static const EdgeInsets zero = EdgeInsets.zero;

  // All sides
  static const EdgeInsets allXSmall = EdgeInsets.all(
    AppDimensions.paddingXSmall,
  );
  static const EdgeInsets allSmall = EdgeInsets.all(AppDimensions.paddingSmall);
  static const EdgeInsets allMedium = EdgeInsets.all(
    AppDimensions.paddingMedium,
  );
  static const EdgeInsets allLarge = EdgeInsets.all(AppDimensions.paddingLarge);
  static const EdgeInsets allXLarge = EdgeInsets.all(
    AppDimensions.paddingXLarge,
  );

  // Horizontal
  static const EdgeInsets horizontalSmall = EdgeInsets.symmetric(
    horizontal: AppDimensions.paddingSmall,
  );
  static const EdgeInsets horizontalMedium = EdgeInsets.symmetric(
    horizontal: AppDimensions.paddingMedium,
  );
  static const EdgeInsets horizontalLarge = EdgeInsets.symmetric(
    horizontal: AppDimensions.paddingLarge,
  );

  // Vertical
  static const EdgeInsets verticalSmall = EdgeInsets.symmetric(
    vertical: AppDimensions.paddingSmall,
  );
  static const EdgeInsets verticalMedium = EdgeInsets.symmetric(
    vertical: AppDimensions.paddingMedium,
  );
  static const EdgeInsets verticalLarge = EdgeInsets.symmetric(
    vertical: AppDimensions.paddingLarge,
  );

  // Screen padding (common for scaffold body)
  static const EdgeInsets screen = EdgeInsets.all(AppDimensions.paddingMedium);
  static const EdgeInsets screenHorizontal = EdgeInsets.symmetric(
    horizontal: AppDimensions.paddingMedium,
  );
}

// ========== SIZED BOX SHORTCUTS ==========
class AppSpacing {
  AppSpacing._();

  // Horizontal spacing
  static const SizedBox hXSmall = SizedBox(width: AppDimensions.paddingXSmall);
  static const SizedBox hSmall = SizedBox(width: AppDimensions.paddingSmall);
  static const SizedBox hMedium = SizedBox(width: AppDimensions.paddingMedium);
  static const SizedBox hLarge = SizedBox(width: AppDimensions.paddingLarge);

  // Vertical spacing
  static const SizedBox vXSmall = SizedBox(height: AppDimensions.paddingXSmall);
  static const SizedBox vSmall = SizedBox(height: AppDimensions.paddingSmall);
  static const SizedBox vMedium = SizedBox(height: AppDimensions.paddingMedium);
  static const SizedBox vLarge = SizedBox(height: AppDimensions.paddingLarge);
  static const SizedBox vXLarge = SizedBox(height: AppDimensions.paddingXLarge);
}

// ========== BORDER RADIUS SHORTCUTS ==========
class AppBorderRadius {
  AppBorderRadius._();

  static BorderRadius get small =>
      BorderRadius.circular(AppDimensions.radiusSmall);
  static BorderRadius get medium =>
      BorderRadius.circular(AppDimensions.radiusMedium);
  static BorderRadius get large =>
      BorderRadius.circular(AppDimensions.radiusLarge);
  static BorderRadius get round =>
      BorderRadius.circular(AppDimensions.radiusRound);
  static BorderRadius get circle =>
      BorderRadius.circular(AppDimensions.radiusCircle);

  // Top only (for bottom sheets)
  static BorderRadius get topMedium => const BorderRadius.vertical(
    top: Radius.circular(AppDimensions.radiusMedium),
  );
  static BorderRadius get topLarge => const BorderRadius.vertical(
    top: Radius.circular(AppDimensions.radiusLarge),
  );
}
