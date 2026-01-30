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
  // Static variables to persist data during app session (but not after restart)
  static double _calculatedFare = 0;
  static double? _mapDistance;
  static String? _mapFromArea;
  static String? _mapToArea;

  // Route matching from map
  static List<JeepneyRoute> _suggestedRoutes = [];
  static Map<int, double> _routeMatchPercentages =
      {}; // routeId -> matchPercentage
  static List<MultiTransferRoute> _multiTransferRoutes = [];
  static List<SuggestedRoute> _hybridSuggestedRoutes =
      []; // New: hybrid routing results
  static HybridRoutingResult? _hybridResult; // New: full hybrid result
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

              // Default state when not used
              if (_calculatedFare == 0)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.map,
                        size: 64,
                        color: AppColors.darkBlue.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No Route Selected',
                        style: GoogleFonts.slackey(
                          fontSize: 20,
                          color: AppColors.darkBlue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Use the map calculator below to select your origin and destination points',
                        style: TextStyle(fontSize: 14, color: AppColors.gray),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
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
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
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
                        color: Colors.black.withValues(alpha: 0.1),
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
                                  color: AppColors.lightGray.withValues(
                                    alpha: 0.5,
                                  ),
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
                                color: AppColors.primary.withValues(
                                  alpha: 0.15,
                                ),
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
                                      color: AppColors.primary.withValues(
                                        alpha: 0.8,
                                      ),
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
                            color: AppColors.lightGray.withValues(alpha: 0.3),
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
                        color: Colors.black.withValues(alpha: 0.1),
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
                                    ? Colors.orange.withValues(alpha: 0.2)
                                    : Colors.green.withValues(alpha: 0.2),
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
                          color: AppColors.lightGray.withValues(alpha: 0.3),
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
                  color: AppColors.white.withValues(alpha: 0.9),
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
        onTap: () {
          // Navigate to search page with route selected
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  MainNavigation(initialIndex: 1, autoSelectRouteId: route.id),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
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
              Row(
                children: [
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
                ],
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (route.distanceKm != null)
                    _buildSummaryItem(Icons.straighten, route.distanceDisplay),
                  if (route.terminal != null)
                    Expanded(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              route.terminal!,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[700],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
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

  /// Get color for match percentage badge
  // ignore: unused_element - Reserved for match percentage UI
  Color _getMatchColor(double percentage) {
    if (percentage >= 80) return Colors.green;
    if (percentage >= 60) return Colors.orange;
    return Colors.blue;
  }

  /// Build a card for multi-transfer routes
  Widget _buildMultiTransferCard(int rank, MultiTransferRoute multiRoute) {
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
        onTap: () {
          // Navigate to search with first route of the multi-transfer
          if (multiRoute.segments.isNotEmpty) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => MainNavigation(
                  initialIndex: 1,
                  autoSelectRouteId: multiRoute.segments.first.route.id,
                ),
              ),
            );
          }
        },
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
                  child: Row(
                    children: [
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
                      const SizedBox(width: 8),
                      Text(
                        '₱${segment.fare.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkBlue,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const Divider(height: 20),
              // Summary
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSummaryItem(
                    Icons.straighten,
                    '${multiRoute.totalDistanceKm.toStringAsFixed(1)} km',
                  ),
                  _buildSummaryItem(
                    Icons.directions_walk,
                    '${multiRoute.totalWalkingDistanceMeters.toStringAsFixed(0)}m walk',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build a card for hybrid routing results (matching search screen UI)
  Widget _buildHybridRouteCard(int rank, SuggestedRoute suggestedRoute) {
    // Get rank colors and icons
    final rankColors = [
      Colors.amber[700]!, // Gold
      Colors.grey[600]!, // Silver
      Colors.brown[600]!, // Bronze
    ];
    final rankIcons = [Icons.looks_one, Icons.looks_two, Icons.looks_3];

    final routes = suggestedRoute.routes;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: routes.isNotEmpty
            ? () {
                // Extract all route IDs from the suggested route
                final routeIds = routes.map((r) => r.id).toList();

                // Navigate to search screen with ALL routes selected
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MainNavigation(
                      initialIndex: 1, // Search tab
                      autoSelectRouteIds: routeIds, // Pass all route IDs
                    ),
                  ),
                );
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Rank and route type
              Row(
                children: [
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: suggestedRoute.transferCount == 0
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      suggestedRoute.transferCount == 0
                          ? 'Direct'
                          : '${suggestedRoute.transferCount} Transfer${suggestedRoute.transferCount > 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: suggestedRoute.transferCount == 0
                            ? Colors.green[700]
                            : Colors.orange[700],
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '\u20b1${suggestedRoute.totalFare.toStringAsFixed(2)}',
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
              ...suggestedRoute.segments.asMap().entries.map((entry) {
                final segment = entry.value;
                final isLast = entry.key == suggestedRoute.segments.length - 1;

                if (segment.type == JourneySegmentType.walking) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.directions_walk,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Walk ${(segment.distanceKm * 1000).toStringAsFixed(0)}m',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  );
                } else if (segment.type == JourneySegmentType.jeepneyRide) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
                    child: Row(
                      children: [
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
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '\u20b1${segment.fare.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkBlue,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              }),
              const Divider(height: 20),
              // Summary
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSummaryItem(
                    Icons.access_time,
                    '~${suggestedRoute.estimatedTimeMinutes.toStringAsFixed(0)} min',
                  ),
                  _buildSummaryItem(
                    Icons.directions_walk,
                    '${(suggestedRoute.totalWalkingDistanceKm * 1000).toStringAsFixed(0)}m walk',
                  ),
                  _buildSummaryItem(
                    Icons.straighten,
                    '${suggestedRoute.totalDistanceKm.toStringAsFixed(1)} km',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 11, color: Colors.grey[700])),
      ],
    );
  }

  Widget _buildPlaceholderRoute(int rank, String name, String description) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.lightGray.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.lightGray.withValues(alpha: 0.5),
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
                  ? AppColors.darkBlue.withValues(alpha: 0.8)
                  : AppColors.gray.withValues(alpha: 0.6),
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
                    color: AppColors.gray.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: AppColors.gray.withValues(alpha: 0.5),
            size: 20,
          ),
        ],
      ),
    );
  }
}
