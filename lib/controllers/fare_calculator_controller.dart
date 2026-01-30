// Fare Calculator Controller
// Manages state and business logic for fare calculation

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../models/jeepney_route.dart';
import '../utils/multi_transfer_matcher.dart';
import '../utils/transit_routing/transit_routing.dart';
import '../services/api_service.dart';

/// Data class for fare calculation result
class FareCalculationResult {
  final double fare;
  final double distance;
  final String? fromArea;
  final String? toArea;
  final LatLng? fromPoint;
  final LatLng? toPoint;
  final List<MatchedRoute> matchedRoutes;
  final List<MultiTransferRoute> multiTransferRoutes;
  final List<SuggestedRoute> suggestedRoutes;
  final HybridRoutingResult? hybridResult;

  FareCalculationResult({
    required this.fare,
    required this.distance,
    this.fromArea,
    this.toArea,
    this.fromPoint,
    this.toPoint,
    this.matchedRoutes = const [],
    this.multiTransferRoutes = const [],
    this.suggestedRoutes = const [],
    this.hybridResult,
  });

  bool get hasRoutes =>
      matchedRoutes.isNotEmpty ||
      multiTransferRoutes.isNotEmpty ||
      suggestedRoutes.isNotEmpty;
  bool get isEmpty => fare == 0;
}

/// Represents a matched route with percentage
class MatchedRoute {
  final JeepneyRoute route;
  final double matchPercentage;

  MatchedRoute({required this.route, required this.matchPercentage});
}

/// Controller for fare calculator screen
class FareCalculatorController extends ChangeNotifier {
  // Fare calculation constants
  static const double baseFare = 13.0;
  static const double perKmRate = 1.80;
  static const double minimumDistance = 4.0;

  // State
  FareCalculationResult _result = FareCalculationResult(fare: 0, distance: 0);
  bool _isLoading = false;
  String? _error;

  // Getters
  FareCalculationResult get result => _result;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasResult => !_result.isEmpty;

  /// Update the result from map calculator
  void updateFromMapResult(Map<String, dynamic> data) {
    final matchedRoutes = <MatchedRoute>[];
    if (data['matchedRoutes'] != null) {
      for (var match in data['matchedRoutes'] as List) {
        final route = match['route'] as JeepneyRoute;
        final percentage = match['matchPercentage'] as double;
        matchedRoutes.add(
          MatchedRoute(route: route, matchPercentage: percentage),
        );
      }
    }

    final multiTransferRoutes = data['multiTransferRoutes'] != null
        ? (data['multiTransferRoutes'] as List).cast<MultiTransferRoute>()
        : <MultiTransferRoute>[];

    final suggestedRoutes = data['suggestedRoutes'] != null
        ? (data['suggestedRoutes'] as List).cast<SuggestedRoute>()
        : <SuggestedRoute>[];

    final hybridResult = data['hybridResult'] as HybridRoutingResult?;

    _result = FareCalculationResult(
      fare: data['fare'] as double,
      distance: data['distance'] as double,
      fromArea: data['from'] as String?,
      toArea: data['to'] as String?,
      matchedRoutes: matchedRoutes,
      multiTransferRoutes: multiTransferRoutes,
      suggestedRoutes: suggestedRoutes,
      hybridResult: hybridResult,
    );

    _error = null;
    notifyListeners();
  }

  /// Calculate fare from distance
  double calculateFare(double distanceKm, {String? discountType}) {
    double fare;
    if (distanceKm <= minimumDistance) {
      fare = baseFare;
    } else {
      fare = baseFare + ((distanceKm - minimumDistance) * perKmRate);
    }

    // Apply discount if applicable
    if (discountType == 'student' || discountType == 'senior') {
      fare = fare * 0.80; // 20% discount
    }

    return fare;
  }

  /// Calculate fare using API (with local fallback)
  Future<double> calculateFareAsync({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
    required double distance,
    String? discountType,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final apiService = ApiService();
      final result = await apiService.calculateFare(
        fromLat: fromLat,
        fromLng: fromLng,
        toLat: toLat,
        toLng: toLng,
        distance: distance,
        discountType: discountType,
      );

      _isLoading = false;
      notifyListeners();

      return result.finalFare;
    } catch (e) {
      _isLoading = false;
      _error = 'Failed to calculate fare: $e';
      notifyListeners();

      // Fallback to local calculation
      return calculateFare(distance, discountType: discountType);
    }
  }

  /// Clear all calculation results
  void clear() {
    _result = FareCalculationResult(fare: 0, distance: 0);
    _error = null;
    notifyListeners();
  }

  /// Get sorted routes by match percentage
  List<MatchedRoute> get sortedMatchedRoutes {
    final routes = List<MatchedRoute>.from(_result.matchedRoutes);
    routes.sort((a, b) => b.matchPercentage.compareTo(a.matchPercentage));
    return routes;
  }

  /// Get direct routes only (single jeepney ride)
  List<MatchedRoute> get directRoutes {
    return sortedMatchedRoutes.where((r) => r.matchPercentage >= 50).toList();
  }

  /// Get multi-transfer routes sorted by score
  List<MultiTransferRoute> get sortedMultiTransferRoutes {
    final routes = List<MultiTransferRoute>.from(_result.multiTransferRoutes);
    routes.sort((a, b) => a.score.compareTo(b.score)); // Lower score is better
    return routes;
  }

  /// Get hybrid suggested routes sorted by travel time
  List<SuggestedRoute> get sortedSuggestedRoutes {
    final routes = List<SuggestedRoute>.from(_result.suggestedRoutes);
    routes.sort(
      (a, b) => a.estimatedTimeMinutes.compareTo(b.estimatedTimeMinutes),
    );
    return routes;
  }
}
