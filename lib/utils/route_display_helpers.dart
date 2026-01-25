import 'dart:math';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Calculate bearing (direction) between two points in degrees
double calculateBearing(LatLng from, LatLng to) {
  double deltaLat = to.latitude - from.latitude;
  double deltaLng = to.longitude - from.longitude;
  double bearing = (atan2(deltaLng, deltaLat) * (180 / pi)) - 90;
  return bearing;
}

/// Calculate Haversine distance between two points in meters
double calculateDistance(LatLng from, LatLng to) {
  const Distance distance = Distance();
  return distance.as(LengthUnit.Meter, from, to);
}

/// Get contrast color (black or white) based on background color luminance
Color getContrastColor(Color backgroundColor) {
  double luminance =
      (0.299 * backgroundColor.red +
          0.587 * backgroundColor.green +
          0.114 * backgroundColor.blue) /
      255;
  return luminance > 0.5 ? Colors.black : Colors.white;
}

/// Calculate points along route path at specified interval (in meters)
List<ArrowPoint> calculateArrowPoints(
  List<LatLng> path,
  double intervalMeters,
) {
  if (path.length < 2) return [];

  List<ArrowPoint> arrowPoints = [];
  double accumulatedDistance = 0;
  double nextArrowDistance = intervalMeters;

  for (int i = 0; i < path.length - 1; i++) {
    LatLng current = path[i];
    LatLng next = path[i + 1];
    double segmentDistance = calculateDistance(current, next);

    // Check if we need to place arrow(s) in this segment
    while (accumulatedDistance + segmentDistance >= nextArrowDistance) {
      // Calculate how far along this segment the arrow should be
      double remainingToArrow = nextArrowDistance - accumulatedDistance;
      double ratio = remainingToArrow / segmentDistance;

      // Interpolate position
      double arrowLat =
          current.latitude + (next.latitude - current.latitude) * ratio;
      double arrowLng =
          current.longitude + (next.longitude - current.longitude) * ratio;
      LatLng arrowPosition = LatLng(arrowLat, arrowLng);

      // Calculate bearing for arrow rotation
      double bearing = calculateBearing(current, next);

      arrowPoints.add(ArrowPoint(position: arrowPosition, bearing: bearing));

      nextArrowDistance += intervalMeters;
    }

    accumulatedDistance += segmentDistance;
  }

  return arrowPoints;
}

/// Data class for arrow marker information
class ArrowPoint {
  final LatLng position;
  final double bearing;

  ArrowPoint({required this.position, required this.bearing});
}

/// Parse hex color string to Color object
Color? parseHexColor(String? hexColor) {
  if (hexColor == null || hexColor.isEmpty) return null;

  String hex = hexColor.replaceAll('#', '').trim();

  // Handle 3-digit hex (e.g., #F00 -> #FF0000)
  if (hex.length == 3) {
    hex = hex.split('').map((c) => c + c).join();
  }

  // Add alpha channel if not present
  if (hex.length == 6) {
    hex = 'FF$hex';
  }

  try {
    return Color(int.parse(hex, radix: 16));
  } catch (e) {
    return null;
  }
}
