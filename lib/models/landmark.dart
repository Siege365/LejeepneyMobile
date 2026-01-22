class Landmark {
  final int id;
  final String name;
  final String category;
  final String? description;
  final double latitude;
  final double longitude;
  final String? iconUrl;
  final List<String> galleryUrls;
  final bool isFeatured;
  final double? distance; // Distance from user (when using nearby endpoint)

  Landmark({
    required this.id,
    required this.name,
    required this.category,
    this.description,
    required this.latitude,
    required this.longitude,
    this.iconUrl,
    this.galleryUrls = const [],
    this.isFeatured = false,
    this.distance,
  });

  factory Landmark.fromJson(Map<String, dynamic> json) {
    return Landmark(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      category: json['category'] ?? 'other',
      description: json['description'],
      latitude:
          _parseDouble(json['latitude']) ??
          _parseDouble(json['coordinates']?['lat']) ??
          0.0,
      longitude:
          _parseDouble(json['longitude']) ??
          _parseDouble(json['coordinates']?['lng']) ??
          0.0,
      iconUrl: json['icon_url'],
      galleryUrls: json['gallery_urls'] != null
          ? List<String>.from(json['gallery_urls'])
          : [],
      isFeatured: json['is_featured'] ?? false,
      distance: _parseDouble(json['distance']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'icon_url': iconUrl,
      'gallery_urls': galleryUrls,
      'is_featured': isFeatured,
    };
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  // Helper to get category display name
  String get categoryDisplayName {
    switch (category) {
      case 'city_center':
        return 'Downtown';
      case 'mall':
        return 'Malls';
      case 'school':
        return 'Schools';
      case 'hospital':
        return 'Hospitals';
      case 'transport':
        return 'Transport';
      default:
        return 'Other';
    }
  }

  // Helper to convert category to API category
  static String toCategoryApi(String displayCategory) {
    switch (displayCategory.toLowerCase()) {
      case 'downtown':
        return 'city_center';
      case 'malls':
        return 'mall';
      case 'schools':
        return 'school';
      case 'hospitals':
        return 'hospital';
      case 'transport':
        return 'transport';
      default:
        return 'other';
    }
  }
}
