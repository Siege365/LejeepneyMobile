import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import '../../constants/app_colors.dart';
import '../../models/jeepney_route.dart';
import '../../services/api_service.dart';
import '../../services/route_calculation_service.dart';
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
  static String? _mapFromArea;
  static String? _mapToArea;
  static LatLng? _pointA; // Store actual coordinates
  static LatLng? _pointB; // Store actual coordinates
  static List<LatLng> _routePath = []; // Store route path

  // Route matching from map
  static List<JeepneyRoute> _suggestedRoutes = [];
  static Map<int, double> _routeMatchPercentages =
      {}; // routeId -> matchPercentage
  static List<MultiTransferRoute> _multiTransferRoutes = [];
  static List<SuggestedRoute> _hybridSuggestedRoutes =
      []; // New: hybrid routing results
  bool _isLoadingRoutes = false;

  // Service following dependency injection pattern
  final RouteCalculationService _routeCalculationService =
      RouteCalculationService(apiService: ApiService());

  /// Recalculate routes after swapping points
  /// Delegates to service layer - UI only handles state updates
  Future<void> _recalculateRoutes() async {
    if (_pointA == null || _pointB == null) {
      setState(() {
        _isLoadingRoutes = false;
      });
      return;
    }

    try {
      final result = await _routeCalculationService.calculateRoutes(
        origin: _pointA!,
        destination: _pointB!,
        osrmPath: _routePath.isNotEmpty ? _routePath : null,
      );

      if (!result.success) {
        throw Exception(result.errorMessage ?? 'Unknown error');
      }

      if (mounted) {
        setState(() {
          _calculatedFare = result.calculatedFare;
          _suggestedRoutes = result.suggestedRoutes;
          _routeMatchPercentages = result.routeMatchPercentages;
          _multiTransferRoutes = result.legacyMultiTransfer;
          _hybridSuggestedRoutes = result.hybridSuggestedRoutes;
          _isLoadingRoutes = false;
        });
      }
    } catch (e) {
      debugPrint('Error recalculating routes: $e');
      if (mounted) {
        setState(() {
          _isLoadingRoutes = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to calculate route: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 10),
              // Title
              Text(
                'Fare Calculator',
                style: GoogleFonts.slackey(
                  fontSize: 28,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Calculate your jeepney fare',
                style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 4),

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

                        // Store coordinates and route path for swap functionality
                        _pointA = data['pointA'] as LatLng?;
                        _pointB = data['pointB'] as LatLng?;
                        if (data['routePath'] != null) {
                          _routePath = (data['routePath'] as List)
                              .cast<LatLng>();
                        } else {
                          _routePath = [];
                        }

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

              const SizedBox(height: 8),

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
                        textAlign: TextAlign.justify,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 4),

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
                          // Swap icon - Tap to swap points
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: IconButton(
                              icon: Icon(
                                Icons.swap_horiz,
                                color: AppColors.darkBlue,
                                size: 32,
                              ),
                              onPressed: () async {
                                // Swap Point A and Point B
                                final tempArea = _mapFromArea;
                                final tempPoint = _pointA;
                                setState(() {
                                  _mapFromArea = _mapToArea;
                                  _mapToArea = tempArea;
                                  _pointA = _pointB;
                                  _pointB = tempPoint;
                                  _isLoadingRoutes = true;
                                });

                                // Recalculate routes with swapped points
                                await _recalculateRoutes();
                              },
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
                        ],
                      ),
                      const SizedBox(height: 2),
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
                                textAlign: TextAlign.justify,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              // Fare Info
              const SizedBox(height: 14),
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
                      '• Student/Senior/PWD discount: 20%',
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
      Colors.amber[700]!, // Gold - 1st
      Colors.grey[600]!, // Silver - 2nd
      Colors.brown[600]!, // Bronze - 3rd
      Colors.blue[600]!, // Blue - 4th
      Colors.blue[600]!, // Blue - 5th
    ];
    final rankIcons = [
      Icons.looks_one,
      Icons.looks_two,
      Icons.looks_3,
      Icons.looks_4,
      Icons.looks_5,
    ];

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
                  if (rank <= 5)
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\u20b1${suggestedRoute.totalFare.toStringAsFixed(2)}',
                        style: GoogleFonts.slackey(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkBlue,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '\u20b1${suggestedRoute.discountedFare.toStringAsFixed(2)} w/ 20% discount',
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
              ),
              const SizedBox(height: 16),
              // Journey Steps Header
              Container(
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
              ),
              const SizedBox(height: 12),
              // Route segments
              ...suggestedRoute.segments.asMap().entries.map((entry) {
                final segment = entry.value;
                final isLast = entry.key == suggestedRoute.segments.length - 1;

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
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
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
                                '${(segment.distanceKm).toStringAsFixed(1)} km • ~${segment.estimatedTimeMinutes.toStringAsFixed(0)} min',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                ),
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
              const SizedBox(height: 8),
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
