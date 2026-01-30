// Landmark Repository
// Manages landmark data with caching and state management

import '../models/landmark.dart';
import '../services/api_service.dart';
import 'base_repository.dart';

class LandmarkRepository extends BaseRepository<List<Landmark>> {
  final ApiService _apiService;

  // State
  List<Landmark> _landmarks = [];
  List<Landmark> _featuredLandmarks = [];
  bool _isLoading = false;
  String? _error;
  String _selectedCategory = 'All';

  // Cache keys
  static const String _allLandmarksKey = 'all_landmarks';
  static const String _featuredKey = 'featured_landmarks';

  LandmarkRepository({ApiService? apiService})
    : _apiService = apiService ?? ApiService();

  // Getters
  List<Landmark> get landmarks => List.unmodifiable(_landmarks);
  List<Landmark> get featuredLandmarks => List.unmodifiable(_featuredLandmarks);
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get selectedCategory => _selectedCategory;
  bool get hasLandmarks => _landmarks.isNotEmpty;

  /// Get landmarks filtered by current category
  List<Landmark> get filteredLandmarks {
    if (_selectedCategory == 'All') return _landmarks;
    return _landmarks
        .where(
          (l) => l.category.toLowerCase() == _selectedCategory.toLowerCase(),
        )
        .toList();
  }

  /// Fetch all landmarks with optional filters
  Future<Result<List<Landmark>>> fetchAllLandmarks({
    String? category,
    bool? featured,
    String? search,
    bool forceRefresh = false,
  }) async {
    final cacheKey = '$_allLandmarksKey${category ?? ''}${search ?? ''}';

    // Check cache
    if (!forceRefresh && isCacheValid(cacheKey)) {
      final cached = getCached(cacheKey);
      if (cached != null) {
        _landmarks = cached;
        notifyListeners();
        return Result.success(cached);
      }
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final landmarks = await _apiService.fetchAllLandmarks(
        category: category,
        featured: featured,
        search: search,
      );

      _landmarks = landmarks;
      setCache(cacheKey, landmarks);
      _isLoading = false;
      notifyListeners();

      return Result.success(landmarks);
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      return Result.failure(e.toString());
    }
  }

  /// Fetch featured landmarks
  Future<Result<List<Landmark>>> fetchFeaturedLandmarks({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && isCacheValid(_featuredKey)) {
      final cached = getCached(_featuredKey);
      if (cached != null) {
        _featuredLandmarks = cached;
        notifyListeners();
        return Result.success(cached);
      }
    }

    try {
      final landmarks = await _apiService.fetchFeaturedLandmarks();
      _featuredLandmarks = landmarks;
      setCache(_featuredKey, landmarks);
      notifyListeners();
      return Result.success(landmarks);
    } catch (e) {
      return Result.failure(e.toString());
    }
  }

  /// Fetch landmarks by category
  Future<Result<List<Landmark>>> fetchByCategory(String category) async {
    final cacheKey = 'category_$category';

    if (isCacheValid(cacheKey)) {
      final cached = getCached(cacheKey);
      if (cached != null) {
        return Result.success(cached);
      }
    }

    try {
      final landmarks = await _apiService.fetchLandmarksByCategory(category);
      setCache(cacheKey, landmarks);
      return Result.success(landmarks);
    } catch (e) {
      return Result.failure(e.toString());
    }
  }

  /// Fetch nearby landmarks
  Future<Result<List<Landmark>>> fetchNearby({
    required double latitude,
    required double longitude,
    double radius = 5.0,
  }) async {
    try {
      final landmarks = await _apiService.fetchNearbyLandmarks(
        latitude: latitude,
        longitude: longitude,
        radius: radius,
      );
      return Result.success(landmarks);
    } catch (e) {
      return Result.failure(e.toString());
    }
  }

  /// Fetch single landmark by ID
  Future<Result<Landmark>> fetchById(int id) async {
    // Check memory first
    try {
      final existing = _landmarks.firstWhere((l) => l.id == id);
      return Result.success(existing);
    } catch (_) {
      // Not found, fetch from API
    }

    try {
      final landmark = await _apiService.fetchLandmarkById(id);
      return Result.success(landmark);
    } catch (e) {
      return Result.failure(e.toString());
    }
  }

  /// Get landmark by ID from memory
  Landmark? getLandmarkById(int id) {
    try {
      return _landmarks.firstWhere((l) => l.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Set selected category filter
  void setCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  /// Search landmarks by name
  List<Landmark> searchLandmarks(String query) {
    if (query.isEmpty) return filteredLandmarks;

    final lowercaseQuery = query.toLowerCase();
    return filteredLandmarks.where((landmark) {
      final description = landmark.description?.toLowerCase() ?? '';
      return landmark.name.toLowerCase().contains(lowercaseQuery) ||
          description.contains(lowercaseQuery) ||
          landmark.category.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }

  /// Refresh all data
  Future<void> refresh() async {
    clearAllCache();
    await Future.wait([
      fetchAllLandmarks(forceRefresh: true),
      fetchFeaturedLandmarks(forceRefresh: true),
    ]);
  }

  /// Clear all data
  void clear() {
    _landmarks = [];
    _featuredLandmarks = [];
    _error = null;
    _selectedCategory = 'All';
    clearAllCache();
    notifyListeners();
  }
}
