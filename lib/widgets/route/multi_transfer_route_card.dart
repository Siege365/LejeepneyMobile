// Reusable Multi-Transfer Route Card Widget
// Displays routes that require transfers between jeepneys

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../utils/multi_transfer_matcher.dart';

class MultiTransferRouteCard extends StatelessWidget {
  final MultiTransferRoute multiRoute;
  final int rank;
  final VoidCallback? onTap;

  const MultiTransferRouteCard({
    super.key,
    required this.multiRoute,
    required this.rank,
    this.onTap,
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
              // Header row with rank and transfer count
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
                  // Transfer count badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${multiRoute.transferCount} Transfer${multiRoute.transferCount > 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[700],
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Total fare
                  Text(
                    '₱${multiRoute.totalFare.toStringAsFixed(2)}',
                    style: GoogleFonts.slackey(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkBlue,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Route segments
              ...multiRoute.segments.asMap().entries.map((entry) {
                final segIndex = entry.key;
                final segment = entry.value;
                final isLast = segIndex == multiRoute.segments.length - 1;

                return Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
                  child: _buildSegmentRow(segment),
                );
              }),

              const Divider(height: 20),

              // Summary row
              _buildSummaryRow(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentRow(RouteSegment segment) {
    return Row(
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
        // Route info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ride: ${segment.route.routeNumber}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkBlue,
                ),
              ),
              Text(
                segment.route.name,
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Segment fare
        Text(
          '₱${segment.fare.toStringAsFixed(2)}',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.darkBlue,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Walking distance if any
        if (multiRoute.totalWalkingDistanceMeters > 0)
          Row(
            children: [
              Icon(Icons.directions_walk, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                '${(multiRoute.totalWalkingDistanceMeters / 1000).toStringAsFixed(1)} km walk',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        // Total distance
        Row(
          children: [
            Icon(Icons.straighten, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              '${multiRoute.totalDistanceKm.toStringAsFixed(1)} km',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ],
    );
  }
}
