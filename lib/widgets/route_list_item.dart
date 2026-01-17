import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

class RouteListItem extends StatelessWidget {
  final String routeName;
  final bool isAvailable;
  final VoidCallback? onTap;

  const RouteListItem({
    super.key,
    required this.routeName,
    required this.isAvailable,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.lightGray.withOpacity(0.3),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            // Route Name
            Expanded(
              child: Text(
                routeName,
                style: GoogleFonts.slackey(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            // Divider
            Container(
              width: 2,
              height: 24,
              color: AppColors.gray.withOpacity(0.3),
            ),
            const SizedBox(width: 16),
            // Show Routes Button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.darkBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.route, color: AppColors.white, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    'Show Routes',
                    style: GoogleFonts.slackey(
                      fontSize: 10,
                      color: AppColors.white,
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
