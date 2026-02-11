/// Transit Routing System
///
/// A hybrid transit routing system that combines OSRM path validation
/// with jeepney-based pathfinding for accurate route suggestions.
///
/// ## Usage
/// ```dart
/// import 'package:lejeepney/utils/transit_routing/transit_routing.dart';
///
/// final router = HybridTransitRouter();
/// final result = await router.findRoutes(
///   origin: userLocation,
///   destination: targetLocation,
///   jeepneyRoutes: routes,
///   osrmPath: calculatedPath,
///   landmarks: landmarkData,
/// );
///
/// for (final route in result.suggestedRoutes) {
///   print('${route.routeNames}: ₱${route.totalFare}');
/// }
/// ```
library;

// Models
export 'models.dart';

// Utilities
export 'geo_utils.dart';

// Components
export 'route_validator.dart';
export 'transit_graph.dart';
export 'jeepney_pathfinder.dart';

// Main Router
export 'hybrid_router.dart';
