// Reusable Route Card Widget
// Displays a single direct jeepney route with rank badge and fare

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../models/jeepney_route.dart';

class DirectRouteCard extends StatelessWidget {
  final JeepneyRoute route;
  final int rank;
  final VoidCallback? onTap;
  final double? matchPercentage;

  const DirectRouteCard({
    super.key,
    required this.route,
    required this.rank,
    this.onTap,
    this.matchPercentage,
  });

  @override
  Widget build(BuildContext context) {
    final rankColors = [
      Colors.amber[700]!, // Gold
      Colors.grey[600]!, // Silver
      Colors.brown[600]!, // Bronze
    ];
    final rankIcons = [Icons.looks_one, Icons.looks_two, Icons.looks_3];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with rank and fare
              Row(
                children: [
                  // Rank badge
                  if (rank <= 3)
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: rankColors[rank - 1].withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        rankIcons[rank - 1],
                        size: 18,
                        color: rankColors[rank - 1],
                      ),
                    ),
                  const SizedBox(width: 8),
                  // Direct badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Direct',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Fare
                  Text(
                    route.fareDisplay,
                    style: GoogleFonts.slackey(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkBlue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Route info row
              Row(
                children: [
                  // Bus icon
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.darkBlue,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.directions_bus,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Route details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ride: ${route.routeNumber}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkBlue,
                          ),
                        ),
                        Text(
                          route.name,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Match percentage if available
                  if (matchPercentage != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getMatchColor(
                          matchPercentage!,
                        ).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${matchPercentage!.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _getMatchColor(matchPercentage!),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getMatchColor(double percentage) {
    if (percentage >= 70) return Colors.green[700]!;
    if (percentage >= 50) return Colors.orange[700]!;
    return Colors.red[700]!;
  }
}
