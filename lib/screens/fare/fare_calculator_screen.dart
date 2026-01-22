import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../models/jeepney_route.dart';
import '../../services/api_service.dart';
import 'map_fare_calculator_screen.dart';

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

  // API integration
  final ApiService _apiService = ApiService();
  List<JeepneyRoute> _suggestedRoutes = [];
  bool _isLoadingRoutes = false;
  double? _fromLat;
  double? _fromLng;
  double? _toLat;
  double? _toLng;

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
                      MaterialPageRoute(
                        builder: (context) => const MapFareCalculatorScreen(),
                      ),
                    );
                    if (result != null && mounted) {
                      setState(() {
                        _mapFromArea = result['from'];
                        _mapToArea = result['to'];
                        _calculatedFare = result['fare'];
                        _mapDistance = result['distance'];
                        _fromLat = result['fromLat'];
                        _fromLng = result['fromLng'];
                        _toLat = result['toLat'];
                        _toLng = result['toLng'];
                      });
                      // Fetch route suggestions from API
                      _fetchRouteSuggestions();
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
                      color: AppColors.darkBlue,
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
                  padding: const EdgeInsets.all(24),
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
                      Text(
                        'Estimated Fare',
                        style: GoogleFonts.slackey(
                          fontSize: 18,
                          color: AppColors.darkBlue,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '₱ ${_calculatedFare.toStringAsFixed(2)}',
                        style: GoogleFonts.slackey(
                          fontSize: 42,
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$_mapFromArea → $_mapToArea',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.gray,
                        ),
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
                          Text(
                            'Suggested Jeepney Routes',
                            style: GoogleFonts.slackey(
                              fontSize: 16,
                              color: AppColors.darkBlue,
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
                      // API routes found
                      else if (_suggestedRoutes.isNotEmpty)
                        ..._suggestedRoutes.asMap().entries.map((entry) {
                          final index = entry.key;
                          final route = entry.value;
                          return _buildRouteCard(index + 1, route);
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

  Future<void> _fetchRouteSuggestions() async {
    if (_fromLat == null ||
        _fromLng == null ||
        _toLat == null ||
        _toLng == null) {
      return;
    }

    setState(() {
      _isLoadingRoutes = true;
      _suggestedRoutes = [];
    });

    try {
      final routes = await _apiService.findRoutes(
        fromLat: _fromLat!,
        fromLng: _fromLng!,
        toLat: _toLat!,
        toLng: _toLng!,
        tolerance: 0.5, // 500m tolerance
      );

      if (mounted) {
        setState(() {
          _suggestedRoutes = routes.take(5).toList(); // Max 5 routes
          _isLoadingRoutes = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to fetch routes: $e');
      if (mounted) {
        setState(() {
          _isLoadingRoutes = false;
        });
      }
    }
  }

  Widget _buildRouteCard(int rank, JeepneyRoute route) {
    // Parse route color
    Color routeColor = AppColors.darkBlue;
    if (route.color != null) {
      try {
        routeColor = Color(int.parse(route.color!.replaceFirst('#', '0xFF')));
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: rank == 1
            ? routeColor.withOpacity(0.08)
            : AppColors.lightGray.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: rank == 1
              ? routeColor.withOpacity(0.3)
              : AppColors.lightGray.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: rank == 1 ? routeColor : AppColors.gray.withOpacity(0.6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: rank == 1
                  ? const Icon(Icons.star, color: Colors.white, size: 18)
                  : Text(
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: routeColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        route.routeNumber,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: routeColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        route.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: rank == 1 ? routeColor : AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.attach_money,
                      size: 12,
                      color: AppColors.success,
                    ),
                    Text(
                      route.fareDisplay,
                      style: TextStyle(
                        color: AppColors.success,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (route.distanceKm != null) ...[
                      const SizedBox(width: 12),
                      Icon(Icons.straighten, size: 12, color: AppColors.gray),
                      const SizedBox(width: 2),
                      Text(
                        route.distanceDisplay,
                        style: TextStyle(color: AppColors.gray, fontSize: 12),
                      ),
                    ],
                    if (route.terminal != null) ...[
                      const SizedBox(width: 12),
                      Icon(Icons.location_on, size: 12, color: AppColors.gray),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          route.terminal!,
                          style: TextStyle(color: AppColors.gray, fontSize: 11),
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
            size: 20,
          ),
        ],
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
