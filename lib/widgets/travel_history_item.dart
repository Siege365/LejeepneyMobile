import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

class RecentActivityItem extends StatelessWidget {
  final String date;
  final String route;
  final VoidCallback? onTap;

  const RecentActivityItem({
    super.key,
    required this.date,
    required this.route,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.lightGray.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            // Date
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                date,
                style: GoogleFonts.slackey(
                  fontSize: 11,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Divider
            Container(
              width: 2,
              height: 30,
              color: AppColors.gray.withValues(alpha: 0.3),
            ),
            const SizedBox(width: 12),
            // Route
            Expanded(
              child: Text(
                route,
                style: GoogleFonts.slackey(
                  fontSize: 12,
                  color: AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
