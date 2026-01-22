import 'package:latlong2/latlong.dart';

class JeepneyRoute {
  final int id;
  final String name;
  final String routeNumber;
  final String? terminal;
  final String? destination;
  final double? distanceKm;
  final double baseFare;
  final String? color;
  final String status; // 'available' or 'unavailable'
  final List<LatLng> path;
  final List<Waypoint> waypoints;
  final String? description;

  JeepneyRoute({
    required this.id,
    required this.name,
    required this.routeNumber,
    this.terminal,
    this.destination,
    this.distanceKm,
    required this.baseFare,
    this.color,
    required this.status,
    this.path = const [],
    this.waypoints = const [],
    this.description,
  });

  factory JeepneyRoute.fromJson(Map<String, dynamic> json) {
    // Parse path coordinates
    List<LatLng> parsedPath = [];
    if (json['path'] != null && json['path'] is List) {
      for (var coord in json['path']) {
        double? lat;
        double? lng;

        // Handle both array format [lat, lng] and object format {lat: ..., lng: ...}
        if (coord is List && coord.length >= 2) {
          lat = _parseDouble(coord[0]);
          lng = _parseDouble(coord[1]);
        } else if (coord is Map) {
          lat = _parseDouble(coord['lat'] ?? coord['latitude']);
          lng = _parseDouble(coord['lng'] ?? coord['longitude']);
        }

        if (lat != null && lng != null) {
          parsedPath.add(LatLng(lat, lng));
        }
      }
    }

    // Parse waypoints
    List<Waypoint> parsedWaypoints = [];
    if (json['waypoints'] != null && json['waypoints'] is List) {
      parsedWaypoints = (json['waypoints'] as List)
          .map((w) => Waypoint.fromJson(w))
          .toList();
    }

    // Parse base fare (could be "₱13.00" or just 13.00)
    double parsedBaseFare = 13.0;
    if (json['base_fare'] != null) {
      if (json['base_fare'] is String) {
        final fareStr = (json['base_fare'] as String)
            .replaceAll('₱', '')
            .replaceAll(',', '')
            .trim();
        parsedBaseFare = double.tryParse(fareStr) ?? 13.0;
      } else {
        parsedBaseFare = _parseDouble(json['base_fare']) ?? 13.0;
      }
    }

    // Parse distance (could be "24.11 km" or just 24.11)
    double? parsedDistance;
    if (json['distance'] != null) {
      if (json['distance'] is String) {
        final distStr = (json['distance'] as String)
            .replaceAll('km', '')
            .replaceAll(' ', '')
            .trim();
        parsedDistance = double.tryParse(distStr);
      } else {
        parsedDistance = _parseDouble(json['distance']);
      }
    }

    return JeepneyRoute(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      routeNumber: json['route_number'] ?? '',
      terminal: json['terminal'],
      destination: json['destination'],
      distanceKm: parsedDistance,
      baseFare: parsedBaseFare,
      color: json['color'],
      status: json['status'] ?? 'available',
      path: parsedPath,
      waypoints: parsedWaypoints,
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'route_number': routeNumber,
      'terminal': terminal,
      'destination': destination,
      'distance': distanceKm,
      'base_fare': baseFare,
      'color': color,
      'status': status,
      'path': path.map((p) => [p.latitude, p.longitude]).toList(),
      'waypoints': waypoints.map((w) => w.toJson()).toList(),
      'description': description,
    };
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  bool get isAvailable => status.toLowerCase() == 'available';

  String get displayName {
    if (routeNumber.isEmpty) {
      return name;
    }
    return '$routeNumber - $name';
  }

  String get fareDisplay => '₱${baseFare.toStringAsFixed(2)}';

  String get distanceDisplay =>
      distanceKm != null ? '${distanceKm!.toStringAsFixed(2)} km' : 'N/A';
}

class Waypoint {
  final int id;
  final String name;
  final double latitude;
  final double longitude;
  final int? order;
  final bool isTerminal;

  Waypoint({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.order,
    this.isTerminal = false,
  });

  factory Waypoint.fromJson(Map<String, dynamic> json) {
    return Waypoint(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      latitude: _parseDouble(json['latitude']) ?? 0.0,
      longitude: _parseDouble(json['longitude']) ?? 0.0,
      order: json['order'],
      isTerminal: json['is_terminal'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'order': order,
      'is_terminal': isTerminal,
    };
  }

  LatLng get position => LatLng(latitude, longitude);

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
