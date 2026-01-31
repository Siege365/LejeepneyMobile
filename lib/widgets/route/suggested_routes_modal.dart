// Suggested Routes Modal Widget
// Extracted from SearchScreen for Single Responsibility Principle
// Displays calculated routes with fare, distance, and transfer information

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../utils/transit_routing/transit_routing.dart';

/// Modal widget for displaying suggested routes to a destination
class SuggestedRoutesModal extends StatelessWidget {
  final List<SuggestedRoute> routes;
  final bool isCalculating;
  final String originName;
  final String destinationName;
  final VoidCallback onClose;
  final void Function(SuggestedRoute route) onRouteSelected;

  const SuggestedRoutesModal({
    super.key,
    required this.routes,
    required this.isCalculating,
    required this.originName,
    required this.destinationName,
    required this.onClose,
    required this.onRouteSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHandle(),
          _buildHeader(context),
          Flexible(
            child: isCalculating
                ? const _LoadingState()
                : routes.isEmpty
                ? const _NoRoutesState()
                : _RoutesListView(
                    routes: routes,
                    onRouteSelected: onRouteSelected,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHandle() {
    return Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Suggested Routes',
                style: GoogleFonts.slackey(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkBlue,
                ),
              ),
              const Spacer(),
              if (!isCalculating)
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // From location
          Row(
            children: [
              const Icon(Icons.my_location, color: Colors.blue, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  originName,
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // To location
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.red, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  destinationName,
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
        ],
      ),
    );
  }
}

/// Loading state while calculating routes
class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Finding best routes...',
              style: TextStyle(fontSize: 15, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty state when no routes are found
class _NoRoutesState extends StatelessWidget {
  const _NoRoutesState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.directions_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No routes found',
              style: GoogleFonts.slackey(
                fontSize: 18,
                color: AppColors.darkBlue,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try selecting a different location',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// List view of available routes
class _RoutesListView extends StatelessWidget {
  final List<SuggestedRoute> routes;
  final void Function(SuggestedRoute route) onRouteSelected;

  const _RoutesListView({required this.routes, required this.onRouteSelected});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      shrinkWrap: true,
      itemCount: routes.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final route = routes[index];
        return SuggestedRouteCard(
          route: route,
          rank: index,
          onTap: () => onRouteSelected(route),
        );
      },
    );
  }
}

/// Individual route card widget
class SuggestedRouteCard extends StatelessWidget {
  final SuggestedRoute route;
  final int rank;
  final VoidCallback onTap;

  const SuggestedRouteCard({
    super.key,
    required this.route,
    required this.rank,
    required this.onTap,
  });

  static const List<Color> _rankColors = [
    Color(0xFFFFA000), // Gold - 1st
    Color(0xFF757575), // Silver - 2nd
    Color(0xFF795548), // Bronze - 3rd
    Color(0xFF42A5F5), // Blue - 4th
    Color(0xFF42A5F5), // Blue - 5th
  ];

  static const List<IconData> _rankIcons = [
    Icons.looks_one,
    Icons.looks_two,
    Icons.looks_3,
    Icons.looks_4,
    Icons.looks_5,
  ];

  @override
  Widget build(BuildContext context) {
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
              _buildHeader(),
              const SizedBox(height: 16),
              _buildJourneyStepsHeader(),
              const SizedBox(height: 12),
              _buildSegments(),
              const Divider(height: 20),
              _buildSummary(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        if (rank < 5)
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _rankColors[rank].withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(_rankIcons[rank], size: 18, color: _rankColors[rank]),
          ),
        const SizedBox(width: 8),
        _TransferBadge(transferCount: route.transferCount),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '\u20b1${route.totalFare.toStringAsFixed(2)}',
              style: GoogleFonts.slackey(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.darkBlue,
              ),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '\u20b1${route.discountedFare.toStringAsFixed(2)} w/ 20% discount',
                style: GoogleFonts.openSans(
                  fontSize: 11,
                  color: Colors.green[800],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildJourneyStepsHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.lightGray.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(Icons.route, size: 14, color: Colors.grey[700]),
          const SizedBox(width: 6),
          Text(
            'Journey Steps:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegments() {
    return Column(
      children: route.segments.asMap().entries.map((entry) {
        final segment = entry.value;
        final isLast = entry.key == route.segments.length - 1;

        if (segment.type == JourneySegmentType.walking) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8, left: 4),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.directions_walk,
                    size: 16,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Walk ${(segment.distanceKm * 1000).toStringAsFixed(0)}m',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                      Text(
                        '~${segment.estimatedTimeMinutes.toStringAsFixed(0)} min',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        } else if (segment.type == JourneySegmentType.jeepneyRide) {
          return Container(
            margin: EdgeInsets.only(bottom: isLast ? 0 : 8, left: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.darkBlue.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.darkBlue.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.darkBlue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.directions_bus,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ride: ${segment.route?.routeNumber ?? 'Jeepney'}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkBlue,
                        ),
                      ),
                      if (segment.route?.name != null)
                        Text(
                          segment.route!.name,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 2),
                      Text(
                        '${segment.distanceKm.toStringAsFixed(1)} km • ~${segment.estimatedTimeMinutes.toStringAsFixed(0)} min',
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\u20b1${segment.fare.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkBlue,
                      ),
                    ),
                    Text(
                      '\u20b1${(segment.fare * 0.8).toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }
        return const SizedBox.shrink();
      }).toList(),
    );
  }

  Widget _buildSummary() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _SummaryItem(
          icon: Icons.access_time,
          text: '~${route.estimatedTimeMinutes.toStringAsFixed(0)} min',
        ),
        _SummaryItem(
          icon: Icons.directions_walk,
          text:
              '${(route.totalWalkingDistanceKm * 1000).toStringAsFixed(0)}m walk',
        ),
        _SummaryItem(
          icon: Icons.straighten,
          text: '${route.totalDistanceKm.toStringAsFixed(1)} km',
        ),
      ],
    );
  }
}

/// Badge showing transfer count
class _TransferBadge extends StatelessWidget {
  final int transferCount;

  const _TransferBadge({required this.transferCount});

  @override
  Widget build(BuildContext context) {
    final isDirect = transferCount == 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDirect
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isDirect
            ? 'Direct'
            : '$transferCount Transfer${transferCount > 1 ? 's' : ''}',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isDirect ? Colors.green[700] : Colors.orange[700],
        ),
      ),
    );
  }
}

/// Summary item widget
class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SummaryItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 11, color: Colors.grey[700])),
      ],
    );
  }
}
