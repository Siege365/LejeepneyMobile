import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import '../../constants/app_colors.dart';
import '../../models/landmark.dart';
import '../../services/api_service.dart';

class LandmarksScreen extends StatefulWidget {
  const LandmarksScreen({super.key});

  @override
  State<LandmarksScreen> createState() => _LandmarksScreenState();
}

class _LandmarksScreenState extends State<LandmarksScreen> {
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final ApiService _apiService = ApiService();

  // API data
  List<Landmark> _apiLandmarks = [];
  bool _isLoading = true;
  bool _isUsingApi = false;
  String? _errorMessage;
  Position? _userPosition;

  final List<String> _categories = [
    'All',
    'Downtown',
    'Malls',
    'Schools',
    'Hospitals',
    'Transport',
  ];
  // All landmarks are now provided by the API; no local hardcoded data.

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _getUserLocation();
    await _fetchLandmarks();
  }

  Future<void> _getUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

      _userPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
    } catch (e) {
      // Fallback to Davao City center
      debugPrint('Location error: $e');
    }
  }

  Future<void> _fetchLandmarks() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Use GET endpoint for now (POST nearby has validation issues)
      final landmarks = await _apiService.fetchAllLandmarks();

      if (!mounted) return;

      setState(() {
        _apiLandmarks = landmarks;
        _isUsingApi = true;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('API Error: $e');

      if (!mounted) return;

      setState(() {
        _isUsingApi = false;
        _apiLandmarks = [];
        _isLoading = false;
        _errorMessage = 'Failed to load landmarks';
      });
    }
  }

  // Helper to get icon based on category
  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'city_center':
      case 'downtown':
        return Icons.location_city;
      case 'mall':
      case 'malls':
        return Icons.local_mall;
      case 'school':
      case 'schools':
        return Icons.school;
      case 'hospital':
      case 'hospitals':
        return Icons.local_hospital;
      case 'transport':
        return Icons.directions_bus;
      default:
        return Icons.place;
    }
  }

  // Get filtered landmarks (API only)
  List<Landmark> get _filteredData {
    return _apiLandmarks.where((landmark) {
      final matchesCategory =
          _selectedCategory == 'All' ||
          landmark.categoryDisplayName == _selectedCategory;
      final matchesSearch =
          _searchQuery.isEmpty ||
          landmark.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (landmark.description ?? '').toLowerCase().contains(
            _searchQuery.toLowerCase(),
          );
      return matchesCategory && matchesSearch;
    }).toList();
  }

  // legacy data removed

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Landmarks',
                style: GoogleFonts.slackey(
                  fontSize: 28,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, color: AppColors.gray, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Search landmarks nearby',
                          hintStyle: TextStyle(
                            color: AppColors.gray,
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                    if (_searchQuery.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                        child: Icon(
                          Icons.close,
                          color: AppColors.gray,
                          size: 20,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Results text
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _searchQuery.isEmpty
                    ? 'Popular destinations in Davao'
                    : 'Results for "$_searchQuery"',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary.withOpacity(0.8),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Category Pills
            SizedBox(
              height: 45,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final isSelected = _selectedCategory == category;
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedCategory = category;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.darkBlue
                              : AppColors.white,
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.darkBlue
                                : AppColors.gray.withOpacity(0.3),
                            width: 1.5,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: AppColors.darkBlue.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          category,
                          style: GoogleFonts.slackey(
                            fontSize: 12,
                            color: isSelected
                                ? AppColors.white
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // API Status indicator
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.wifi_off, size: 14, color: AppColors.warning),
                      const SizedBox(width: 6),
                      Text(
                        _errorMessage!,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_errorMessage != null) const SizedBox(height: 8),

            // Landmarks List
            Expanded(
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: AppColors.darkBlue),
                          const SizedBox(height: 16),
                          Text(
                            'Loading landmarks...',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.gray,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _filteredData.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 60,
                            color: AppColors.gray.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No landmarks found',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.gray,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchLandmarks,
                      color: AppColors.darkBlue,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredData.length,
                        itemBuilder: (context, index) {
                          final landmark = _filteredData[index];
                          return _buildApiLandmarkCard(landmark);
                        },
                      ),
                    ),
            ),
            const SizedBox(height: 20), // Space for bottom nav
          ],
        ),
      ),
    );
  }

  // Removed local-map card helper; API card is used exclusively.

  // Build card for API landmark data
  Widget _buildApiLandmarkCard(Landmark landmark) {
    final distanceText = landmark.distance != null
        ? '${landmark.distance!.toStringAsFixed(1)} km'
        : 'N/A';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            // TODO: Navigate to landmark detail or show on map
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Navigate to ${landmark.name}'),
                backgroundColor: AppColors.darkBlue,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon Container or Image
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: landmark.iconUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Image.network(
                            landmark.iconUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              _getCategoryIcon(landmark.category),
                              color: AppColors.darkBlue,
                              size: 35,
                            ),
                          ),
                        )
                      : Icon(
                          _getCategoryIcon(landmark.category),
                          color: AppColors.darkBlue,
                          size: 35,
                        ),
                ),
                const SizedBox(width: 16),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        landmark.name,
                        style: GoogleFonts.slackey(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.success.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              landmark.categoryDisplayName,
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.success,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (landmark.isFeatured) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.star,
                                    size: 10,
                                    color: AppColors.darkBlue,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    'Featured',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: AppColors.darkBlue,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (landmark.description != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          landmark.description!,
                          style: TextStyle(fontSize: 11, color: AppColors.gray),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.directions_walk,
                            size: 14,
                            color: AppColors.darkBlue,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$distanceText away',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.darkBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: AppColors.gray.withOpacity(0.5),
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
