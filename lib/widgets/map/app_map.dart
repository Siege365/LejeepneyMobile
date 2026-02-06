// Reusable App Map Widget
// Wraps FlutterMap with common configuration and styling

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../constants/app_colors.dart';
import '../../utils/resilient_tile_provider.dart';

/// Default center for Davao City
const LatLng davaoCity = LatLng(7.0731, 125.6128);

/// Reusable map widget with common configuration
class AppMap extends StatelessWidget {
  final MapController? mapController;
  final LatLng initialCenter;
  final double initialZoom;
  final Function(TapPosition, LatLng)? onTap;
  final Function(TapPosition, LatLng)? onLongPress;
  final List<Marker> markers;
  final List<Polyline> polylines;
  final List<Polygon> polygons;
  final bool showAttribution;

  const AppMap({
    super.key,
    this.mapController,
    this.initialCenter = davaoCity,
    this.initialZoom = 14.0,
    this.onTap,
    this.onLongPress,
    this.markers = const [],
    this.polylines = const [],
    this.polygons = const [],
    this.showAttribution = true,
  });

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: initialCenter,
        initialZoom: initialZoom,
        onTap: onTap,
        onLongPress: onLongPress,
      ),
      children: [
        // Base tile layer (OpenStreetMap)
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.final_project_cce106',
          maxNativeZoom: 19,
          maxZoom: 19,
          keepBuffer: 2,
          tileProvider: ResilientTileProvider(
            maxRetries: 2,
            retryDelay: const Duration(milliseconds: 500),
            userAgent: 'com.example.final_project_cce106',
          ),
        ),
        // Polygons layer
        if (polygons.isNotEmpty) PolygonLayer(polygons: polygons),
        // Polylines layer
        if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
        // Markers layer
        if (markers.isNotEmpty) MarkerLayer(markers: markers),
        // Attribution
        if (showAttribution)
          const SimpleAttributionWidget(source: Text('OpenStreetMap')),
      ],
    );
  }
}

/// Creates a styled route polyline
Polyline createRoutePolyline({
  required List<LatLng> points,
  Color color = AppColors.darkBlue,
  double strokeWidth = 5.0,
  Color? borderColor,
  double borderStrokeWidth = 2.0,
}) {
  return Polyline(
    points: points,
    color: color,
    strokeWidth: strokeWidth,
    borderColor: borderColor ?? Colors.white,
    borderStrokeWidth: borderStrokeWidth,
  );
}

/// Creates a styled walking path polyline (dashed)
Polyline createWalkingPolyline({
  required List<LatLng> points,
  Color color = Colors.grey,
  double strokeWidth = 3.0,
}) {
  return Polyline(
    points: points,
    color: color,
    strokeWidth: strokeWidth,
    isDotted: true,
  );
}

/// Helper to calculate bounds for a list of points
LatLngBounds? calculateBounds(List<LatLng> points) {
  if (points.isEmpty) return null;
  if (points.length == 1) {
    return LatLngBounds(points.first, points.first);
  }

  double minLat = points.first.latitude;
  double maxLat = points.first.latitude;
  double minLng = points.first.longitude;
  double maxLng = points.first.longitude;

  for (final point in points) {
    minLat = point.latitude < minLat ? point.latitude : minLat;
    maxLat = point.latitude > maxLat ? point.latitude : maxLat;
    minLng = point.longitude < minLng ? point.longitude : minLng;
    maxLng = point.longitude > maxLng ? point.longitude : maxLng;
  }

  return LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng));
}

/// Extension methods for MapController
extension MapControllerExtensions on MapController {
  /// Animate to a single point
  void animateTo(LatLng point, {double? zoom}) {
    move(point, zoom ?? camera.zoom);
  }

  /// Fit the camera to show all points with padding
  void fitBoundsForPoints(
    List<LatLng> points, {
    EdgeInsets padding = const EdgeInsets.all(50),
  }) {
    final bounds = calculateBounds(points);
    if (bounds != null) {
      fitCamera(CameraFit.bounds(bounds: bounds, padding: padding));
    }
  }
}
