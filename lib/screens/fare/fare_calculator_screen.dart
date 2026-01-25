import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../models/jeepney_route.dart';
import '../../utils/page_transitions.dart';
import '../../utils/multi_transfer_matcher.dart';
import '../../utils/transit_routing/transit_routing.dart';
import 'map_fare_calculator_screen.dart';
import '../main_navigation.dart';

class FareCalculatorScreen extends StatefulWidget {
  const FareCalculatorScreen({super.key});

  @override
  State<FareCalculatorScreen> createState() => _FareCalculatorScreenState();
}

class _FareCalculatorScreenState extends State<FareCalculatorScreen> {
  double _calculatedFare = 0;
  double? _mapDistance;
  String? _mapFromArea;
  String? _mapToArea;

  // Route matching from map
  List<JeepneyRoute> _suggestedRoutes = [];
  Map<int, double> _routeMatchPercentages = {}; // routeId -> matchPercentage
  List<MultiTransferRoute> _multiTransferRoutes = [];
  List<SuggestedRoute> _hybridSuggestedRoutes =
      []; // New: hybrid routing results
  HybridRoutingResult? _hybridResult; // New: full hybrid result
  bool _isLoadingRoutes = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 20),
              // Title
              Text(
                'Fare Calculator',
                style: GoogleFonts.slackey(
                  fontSize: 28,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Calculate your jeepney fare',
                style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 16),

              // Map Calculator Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      SlideUpRoute(page: const MapFareCalculatorScreen()),
                    );
                    if (result != null && mounted) {
                      final data = result as Map<String, dynamic>;
                      setState(() {
                        _mapFromArea = data['from'];
                        _mapToArea = data['to'];
                        _calculatedFare = data['fare'];
                        _mapDistance = data['distance'];

                        // Use matched routes from map instead of API call
                        if (data['matchedRoutes'] != null) {
                          _suggestedRoutes = (data['matchedRoutes'] as List)
                              .map((r) => r['route'] as JeepneyRoute)
                              .toList();
                          _routeMatchPercentages = {};
                          for (var match in data['matchedRoutes'] as List) {
                            final route = match['route'] as JeepneyRoute;
                            final percentage =
                                match['matchPercentage'] as double;
                            _routeMatchPercentages[route.id] = percentage;
                          }
                        } else {
                          _suggestedRoutes = [];
                          _routeMatchPercentages = {};
                        }

                        // Handle multi-transfer routes
                        if (data['multiTransferRoutes'] != null) {
                          _multiTransferRoutes =
                              (data['multiTransferRoutes'] as List)
                                  .cast<MultiTransferRoute>();
                        } else {
                          _multiTransferRoutes = [];
                        }

                        // Handle new hybrid routing results
                        if (data['suggestedRoutes'] != null) {
                          _hybridSuggestedRoutes =
                              (data['suggestedRoutes'] as List)
                                  .cast<SuggestedRoute>();
                        } else {
                          _hybridSuggestedRoutes = [];
                        }

                        if (data['hybridResult'] != null) {
                          _hybridResult =
                              data['hybridResult'] as HybridRoutingResult;
                        } else {
                          _hybridResult = null;
                        }

                        _isLoadingRoutes = false;
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.darkBlue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  icon: const Icon(Icons.map, color: AppColors.white),
                  label: Text(
                    'Use Map Calculator',
                    style: GoogleFonts.slackey(
                      fontSize: 14,
                      color: AppColors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Disclaimer Card (Always visible)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: AppColors.textPrimary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Please note: This fare estimate is based on calculated road distance and is accurate most of the time. However, the actual fare may vary depending on your exact drop-off point along the route.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Result Card
              if (_calculatedFare > 0)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Route direction
                      Row(
                        children: [
                          // From (GIKAN)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Point A',
                                  style: GoogleFonts.slackey(
                                    fontSize: 11,
                                    color: Colors.green,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _mapFromArea ?? 'Point A',
                                  style: GoogleFonts.slackey(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          // Swap icon
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Icon(
                              Icons.swap_horiz,
                              color: AppColors.darkBlue,
                              size: 32,
                            ),
                          ),
                          // To (PADULONG)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Point B',
                                  style: GoogleFonts.slackey(
                                    fontSize: 11,
                                    color: Colors.red,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _mapToArea ?? 'Point B',
                                  style: GoogleFonts.slackey(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.right,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Fares
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Regular Fare
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.lightGray.withOpacity(0.5),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'REGULAR FARE',
                                    style: GoogleFonts.slackey(
                                      fontSize: 10,
                                      color: AppColors.gray,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '₱${_calculatedFare.toStringAsFixed(2)}',
                                    style: GoogleFonts.slackey(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Discounted Fare
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'DISCOUNTED',
                                    style: GoogleFonts.slackey(
                                      fontSize: 10,
                                      color: AppColors.primary,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '₱${(_calculatedFare * 0.8).toStringAsFixed(2)}',
                                    style: GoogleFonts.slackey(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Student/Senior/PWD',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: AppColors.primary.withOpacity(0.8),
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_mapDistance != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.lightGray.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.straighten,
                                size: 16,
                                color: AppColors.darkBlue,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Distance: ${_mapDistance!.toStringAsFixed(2)} km',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

              // Suggested Jeepney Routes
              if (_calculatedFare > 0) const SizedBox(height: 16),
              if (_calculatedFare > 0)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.directions_bus,
                            color: AppColors.darkBlue,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Suggested Jeepney Routes',
                              style: GoogleFonts.slackey(
                                fontSize: 16,
                                color: AppColors.darkBlue,
                              ),
                            ),
                          ),
                          // Show routing source badge
                          if (_hybridResult != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _hybridResult!.fallbackUsed
                                    ? Colors.orange.withOpacity(0.2)
                                    : Colors.green.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _hybridResult!.fallbackUsed
                                        ? Icons.alt_route
                                        : Icons.check_circle,
                                    size: 12,
                                    color: _hybridResult!.fallbackUsed
                                        ? Colors.orange
                                        : Colors.green,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _hybridResult!.fallbackUsed
                                        ? 'Jeepney-Based'
                                        : 'Validated',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: _hybridResult!.fallbackUsed
                                          ? Colors.orange
                                          : Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Loading state
                      if (_isLoadingRoutes)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.darkBlue,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Finding optimal routes...',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.gray,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      // Priority 1: Hybrid suggested routes (new algorithm)
                      else if (_hybridSuggestedRoutes.isNotEmpty)
                        ..._hybridSuggestedRoutes.asMap().entries.map((entry) {
                          final index = entry.key;
                          final suggestedRoute = entry.value;
                          return _buildHybridRouteCard(
                            index + 1,
                            suggestedRoute,
                          );
                        })
                      // Priority 2: Legacy direct routes
                      else if (_suggestedRoutes.isNotEmpty)
                        ..._suggestedRoutes.asMap().entries.map((entry) {
                          final index = entry.key;
                          final route = entry.value;
                          return _buildRouteCard(index + 1, route);
                        })
                      // Priority 3: Legacy multi-transfer routes
                      else if (_multiTransferRoutes.isNotEmpty)
                        ..._multiTransferRoutes.asMap().entries.map((entry) {
                          final index = entry.key;
                          final multiRoute = entry.value;
                          return _buildMultiTransferCard(index + 1, multiRoute);
                        })
                      // No routes found - show placeholder
                      else ...[
                        _buildPlaceholderRoute(
                          1,
                          'No direct routes found',
                          'Try adjusting your pickup/drop-off points',
                        ),
                      ],
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.lightGray.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              size: 16,
                              color: AppColors.gray,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Route suggestions are ranked by: directness, transfers, total fare, and estimated time.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.gray,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              // Fare Info
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fare Information',
                      style: GoogleFonts.slackey(
                        fontSize: 14,
                        color: AppColors.darkBlue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• Minimum fare: ₱13.00 (first 4km)',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Text(
                      '• Additional: ₱1.80 per km',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Text(
                      '• Student/Senior discount: 20%',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRouteCard(int rank, JeepneyRoute route) {
    // Parse route color
    Color routeColor = AppColors.darkBlue;
    if (route.color != null) {
      try {
        routeColor = Color(int.parse(route.color!.replaceFirst('#', '0xFF')));
      } catch (_) {}
    }

    // Get rank color (gold, silver, bronze, default)
    Color rankColor;
    IconData rankIcon;
    if (rank == 1) {
      rankColor = const Color(0xFFFFD700); // Gold
      rankIcon = Icons.emoji_events;
    } else if (rank == 2) {
      rankColor = const Color(0xFFC0C0C0); // Silver
      rankIcon = Icons.workspace_premium;
    } else if (rank == 3) {
      rankColor = const Color(0xFFCD7F32); // Bronze
      rankIcon = Icons.military_tech;
    } else {
      rankColor = AppColors.gray.withOpacity(0.6);
      rankIcon = Icons.star_border;
    }

    // Get match percentage if available
    final matchPercentage = _routeMatchPercentages[route.id];

    return GestureDetector(
      onTap: () {
        // Navigate to search page with navbar intact and auto-select route
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                MainNavigation(initialIndex: 1, autoSelectRouteId: route.id),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: rank <= 3
              ? rankColor.withOpacity(0.08)
              : AppColors.lightGray.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: rank <= 3
                ? rankColor.withOpacity(0.3)
                : AppColors.lightGray.withOpacity(0.5),
            width: rank == 1 ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Rank badge
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: rankColor,
                borderRadius: BorderRadius.circular(8),
                boxShadow: rank <= 3
                    ? [
                        BoxShadow(
                          color: rankColor.withOpacity(0.4),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: rank <= 3
                    ? Icon(rankIcon, color: Colors.white, size: 22)
                    : Text(
                        '$rank',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          route.name,
                          style: GoogleFonts.slackey(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Match percentage badge
                      if (matchPercentage != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _getMatchColor(matchPercentage),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${matchPercentage.toStringAsFixed(0)}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        route.fareDisplay,
                        style: GoogleFonts.slackey(
                          color: AppColors.success,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (route.distanceKm != null) ...[
                        const SizedBox(width: 12),
                        Icon(Icons.straighten, size: 13, color: AppColors.gray),
                        const SizedBox(width: 2),
                        Text(
                          route.distanceDisplay,
                          style: TextStyle(color: AppColors.gray, fontSize: 12),
                        ),
                      ],
                      if (route.terminal != null) ...[
                        const SizedBox(width: 12),
                        Icon(
                          Icons.location_on,
                          size: 13,
                          color: AppColors.gray,
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            route.terminal!,
                            style: TextStyle(
                              color: AppColors.gray,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: AppColors.gray.withOpacity(0.5),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  /// Get color for match percentage badge
  Color _getMatchColor(double percentage) {
    if (percentage >= 80) return Colors.green;
    if (percentage >= 60) return Colors.orange;
    return Colors.blue;
  }

  /// Build a card for multi-transfer routes
  Widget _buildMultiTransferCard(int rank, MultiTransferRoute multiRoute) {
    // Get rank color
    Color rankColor;
    IconData rankIcon;
    if (rank == 1) {
      rankColor = const Color(0xFFFFD700); // Gold
      rankIcon = Icons.emoji_events;
    } else if (rank == 2) {
      rankColor = const Color(0xFFC0C0C0); // Silver
      rankIcon = Icons.workspace_premium;
    } else if (rank == 3) {
      rankColor = const Color(0xFFCD7F32); // Bronze
      rankIcon = Icons.military_tech;
    } else {
      rankColor = AppColors.gray.withOpacity(0.6);
      rankIcon = Icons.star_border;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: rank <= 3
            ? rankColor.withOpacity(0.08)
            : AppColors.lightGray.withOpacity(0.2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: rank <= 3
              ? rankColor.withOpacity(0.3)
              : AppColors.lightGray.withOpacity(0.5),
          width: rank == 1 ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with rank and transfer count
          Row(
            children: [
              // Rank badge
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: rankColor,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: rank <= 3
                      ? [
                          BoxShadow(
                            color: rankColor.withOpacity(0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: rank <= 3
                      ? Icon(rankIcon, color: Colors.white, size: 22)
                      : Text(
                          '$rank',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              // Transfer count badge
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.swap_horiz,
                            size: 16,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${multiRoute.transferCount} Transfer${multiRoute.transferCount > 1 ? 's' : ''}',
                            style: GoogleFonts.slackey(
                              fontSize: 11,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Route sequence
                    Text(
                      multiRoute.routeNames,
                      style: GoogleFonts.slackey(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Route segments details
          ...multiRoute.segments.asMap().entries.map((entry) {
            final segIndex = entry.key;
            final segment = entry.value;
            final isLast = segIndex == multiRoute.segments.length - 1;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Segment row
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.darkBlue.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${segIndex + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkBlue,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            segment.route.name,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Route ${segment.route.routeNumber} • ₱${segment.fare.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.gray,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Transfer point (if not last segment)
                if (!isLast && segIndex < multiRoute.transferPoints.length)
                  Padding(
                    padding: const EdgeInsets.only(left: 14, top: 8, bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 2,
                          height: 20,
                          color: Colors.orange.withOpacity(0.5),
                        ),
                        const SizedBox(width: 18),
                        Icon(
                          Icons.directions_walk,
                          size: 16,
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Walk to ${multiRoute.transferPoints[segIndex].landmarkName} (${multiRoute.transferPoints[segIndex].walkingDistanceMeters.toStringAsFixed(0)}m)',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.orange,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          }),

          const SizedBox(height: 12),

          // Summary row
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.payments, size: 18, color: AppColors.success),
                    const SizedBox(width: 6),
                    Text(
                      'Total: ₱${multiRoute.totalFare.toStringAsFixed(2)}',
                      style: GoogleFonts.slackey(
                        fontSize: 14,
                        color: AppColors.success,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Icon(Icons.straighten, size: 14, color: AppColors.gray),
                    const SizedBox(width: 4),
                    Text(
                      '${multiRoute.totalDistanceKm.toStringAsFixed(1)} km',
                      style: TextStyle(fontSize: 12, color: AppColors.gray),
                    ),
                    const SizedBox(width: 10),
                    Icon(
                      Icons.directions_walk,
                      size: 14,
                      color: AppColors.gray,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${multiRoute.totalWalkingDistanceMeters.toStringAsFixed(0)}m',
                      style: TextStyle(fontSize: 12, color: AppColors.gray),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build a card for hybrid routing results (new algorithm)
  Widget _buildHybridRouteCard(int rank, SuggestedRoute suggestedRoute) {
    // Get rank color
    Color rankColor;
    IconData rankIcon;
    if (rank == 1) {
      rankColor = const Color(0xFFFFD700); // Gold
      rankIcon = Icons.emoji_events;
    } else if (rank == 2) {
      rankColor = const Color(0xFFC0C0C0); // Silver
      rankIcon = Icons.workspace_premium;
    } else if (rank == 3) {
      rankColor = const Color(0xFFCD7F32); // Bronze
      rankIcon = Icons.military_tech;
    } else {
      rankColor = AppColors.gray.withOpacity(0.6);
      rankIcon = Icons.format_list_numbered;
    }

    final isDirectRoute = suggestedRoute.transferCount == 0;
    final routes = suggestedRoute.routes;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: rankColor.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: rank <= 3 ? rankColor.withOpacity(0.5) : Colors.transparent,
          width: rank <= 3 ? 2 : 0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: routes.isNotEmpty
            ? () {
                // Navigate to search screen with first route selected
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MainNavigation(
                      initialIndex: 1, // Search tab
                      autoSelectRouteId: routes.first.id,
                    ),
                  ),
                );
              }
            : null,
        child: Column(
          children: [
            // Header row with rank and route summary
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Rank badge
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: rankColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: rankColor.withOpacity(0.4),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: rank <= 3
                          ? Icon(rankIcon, color: Colors.white, size: 22)
                          : Text(
                              '$rank',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Route info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // Transfer count badge
                            if (!isDirectRoute)
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.swap_horiz,
                                      size: 12,
                                      color: Colors.orange,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${suggestedRoute.transferCount} transfer${suggestedRoute.transferCount > 1 ? 's' : ''}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            // Direct route badge
                            if (isDirectRoute)
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      size: 12,
                                      color: Colors.green,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Direct',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Route names
                        Text(
                          suggestedRoute.routeNames.isNotEmpty
                              ? suggestedRoute.routeNames
                              : 'Route unavailable',
                          style: GoogleFonts.slackey(
                            fontSize: 15,
                            color: AppColors.darkBlue,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Fare
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '₱${suggestedRoute.totalFare.toStringAsFixed(2)}',
                      style: GoogleFonts.slackey(
                        fontSize: 14,
                        color: AppColors.success,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Segment details
            if (suggestedRoute.segments.isNotEmpty)
              Container(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Column(
                  children: [
                    ...suggestedRoute.segments.asMap().entries.map((entry) {
                      final index = entry.key;
                      final segment = entry.value;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: segment.isWalking || segment.isTransfer
                              ? Colors.blue.withOpacity(0.05)
                              : AppColors.lightGray.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: segment.isWalking || segment.isTransfer
                                ? Colors.blue.withOpacity(0.2)
                                : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Step indicator
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: segment.isWalking || segment.isTransfer
                                    ? Colors.blue
                                    : AppColors.darkBlue,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: segment.isWalking || segment.isTransfer
                                    ? const Icon(
                                        Icons.directions_walk,
                                        size: 14,
                                        color: Colors.white,
                                      )
                                    : Text(
                                        '${index + 1}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 10),

                            // Segment info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    segment.isWalking
                                        ? 'Walk to ${segment.endName ?? 'stop'}'
                                        : segment.isTransfer
                                        ? 'Transfer at ${segment.endName ?? 'transfer point'}'
                                        : 'Take ${segment.route?.routeNumber ?? 'Route'}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color:
                                          segment.isWalking ||
                                              segment.isTransfer
                                          ? Colors.blue
                                          : AppColors.darkBlue,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.straighten,
                                        size: 12,
                                        color: AppColors.gray,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        segment.distanceKm < 1
                                            ? '${(segment.distanceKm * 1000).toStringAsFixed(0)}m'
                                            : '${segment.distanceKm.toStringAsFixed(1)}km',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.gray,
                                        ),
                                      ),
                                      if (!segment.isWalking &&
                                          !segment.isTransfer) ...[
                                        const SizedBox(width: 12),
                                        Icon(
                                          Icons.payments,
                                          size: 12,
                                          color: AppColors.success,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '₱${segment.fare.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppColors.success,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(width: 12),
                                      Icon(
                                        Icons.timer,
                                        size: 12,
                                        color: AppColors.gray,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '~${segment.estimatedTimeMinutes.toStringAsFixed(0)} min',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.gray,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                    // Summary row
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.darkBlue.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          // Total distance
                          Row(
                            children: [
                              Icon(
                                Icons.straighten,
                                size: 14,
                                color: AppColors.darkBlue,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${suggestedRoute.totalDistanceKm.toStringAsFixed(1)} km',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.darkBlue,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          // Walking distance
                          Row(
                            children: [
                              Icon(
                                Icons.directions_walk,
                                size: 14,
                                color: Colors.blue,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${(suggestedRoute.totalWalkingDistanceKm * 1000).toStringAsFixed(0)}m',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          // Est. time
                          Row(
                            children: [
                              Icon(
                                Icons.timer,
                                size: 14,
                                color: AppColors.gray,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '~${suggestedRoute.estimatedTimeMinutes.toStringAsFixed(0)} min',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.gray,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
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

  Widget _buildPlaceholderRoute(int rank, String name, String description) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.lightGray.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.lightGray.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: rank == 1
                  ? AppColors.darkBlue.withOpacity(0.8)
                  : AppColors.gray.withOpacity(0.6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '$rank',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: rank == 1 ? AppColors.darkBlue : AppColors.gray,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: AppColors.gray.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: AppColors.gray.withOpacity(0.5),
            size: 20,
          ),
        ],
      ),
    );
  }
}
