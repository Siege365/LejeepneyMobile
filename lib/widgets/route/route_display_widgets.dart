// Route Display Widgets - Markers and direction arrows for route visualization
// Extracted from SearchScreen for Single Responsibility Principle

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart'; // Provides pi constant
import '../../models/jeepney_route.dart';
import '../../utils/route_display_helpers.dart';
import '../../constants/map_constants.dart';

/// Builds direction arrow markers along a route path
class RouteDirectionArrows {
  RouteDirectionArrows._();

  /// Build arrow markers for a jeepney route
  /// [route] The jeepney route to display arrows for
  /// [intervalMeters] Distance between arrows (default: 1000m = 1km)
  static List<Marker> build(
    JeepneyRoute route, {
    double intervalMeters = MapConstants.arrowIntervalMeters,
  }) {
    final List<Marker> arrows = [];

    if (route.path.length < 2) return arrows;

    // Calculate arrow positions
    final List<ArrowPoint> arrowPoints = calculateArrowPoints(
      route.path,
      intervalMeters,
    );

    final Color routeColor = parseHexColor(route.color) ?? Colors.blue;
    final Color arrowColor = getContrastColor(routeColor);

    for (final arrowPoint in arrowPoints) {
      arrows.add(_buildArrowMarker(arrowPoint, arrowColor));
    }

    return arrows;
  }

  static Marker _buildArrowMarker(ArrowPoint arrowPoint, Color arrowColor) {
    return Marker(
      point: arrowPoint.position,
      width: 28,
      height: 28,
      child: Transform.rotate(
        angle: arrowPoint.bearing * pi / 180,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.9),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Icon(
            Icons.arrow_forward,
            color: arrowColor,
            size: 18,
            shadows: [
              Shadow(color: Colors.white.withValues(alpha: 0.8), blurRadius: 2),
            ],
          ),
        ),
      ),
    );
  }
}

/// Builds start and end markers for a route
class RouteEndpointMarkers {
  RouteEndpointMarkers._();

  /// Build start and end markers for a jeepney route
  static List<Marker> build(JeepneyRoute route) {
    final List<Marker> markers = [];

    if (route.path.isEmpty) return markers;

    // Start Point Marker
    markers.add(_buildStartMarker(route.path.first));

    // End Point Marker
    markers.add(_buildEndMarker(route.path.last));

    return markers;
  }

  static Marker _buildStartMarker(LatLng point) {
    return Marker(
      point: point,
      width: 50,
      height: 70,
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withValues(alpha: 0.4),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.play_arrow, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'START',
              style: GoogleFonts.slackey(
                fontSize: 8,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Marker _buildEndMarker(LatLng point) {
    return Marker(
      point: point,
      width: 50,
      height: 70,
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.4),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.stop, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'END',
              style: GoogleFonts.slackey(
                fontSize: 8,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Builds polylines for route display on map
class RoutePolylineBuilder {
  RoutePolylineBuilder._();

  /// Build a polyline for a single route
  static Polyline build(JeepneyRoute route) {
    final Color routeColor = parseHexColor(route.color) ?? Colors.blue;

    return Polyline(
      points: route.path,
      color: routeColor,
      strokeWidth: MapConstants.routeStrokeWidth,
      borderStrokeWidth: MapConstants.routeBorderWidth,
      borderColor: Colors.black.withValues(alpha: 0.3),
    );
  }

  /// Build polylines for multiple routes
  static List<Polyline> buildMultiple(List<JeepneyRoute> routes) {
    return routes
        .where((route) => route.path.isNotEmpty)
        .map((route) => build(route))
        .toList();
  }
}
