import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class RecentActivityItem extends StatelessWidget {
  final String? title;
  final String route;
  final String? activityType;
  final VoidCallback? onTap;

  const RecentActivityItem({
    super.key,
    this.title,
    required this.route,
    this.activityType,
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
            // Activity Icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getActivityIcon(),
                color: AppColors.darkBlue,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            // Title and Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null)
                    Text(
                      title!,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (title != null) const SizedBox(height: 2),
                  Text(
                    route,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textPrimary.withValues(alpha: 0.7),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getActivityIcon() {
    if (activityType == null) return Icons.history;

    switch (activityType) {
      case 'route_calculated':
        return Icons.route;
      case 'fare_calculated':
        return Icons.calculate;
      case 'location_search':
        return Icons.search;
      case 'route_saved':
        return Icons.bookmark;
      case 'support_ticket':
      case 'customer_service':
        return Icons.confirmation_number;
      default:
        return Icons.history;
    }
  }
}
