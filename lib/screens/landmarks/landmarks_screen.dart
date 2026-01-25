import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import '../../constants/app_colors.dart';
import '../../models/landmark.dart';
import '../../services/api_service.dart';
import '../main_navigation.dart';

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

      // Recalculate distances if landmarks are already loaded
      if (_apiLandmarks.isNotEmpty) {
        _apiLandmarks = _apiLandmarks.map((landmark) {
          return _calculateDistance(landmark);
        }).toList();
        if (mounted) setState(() {});
      }
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

      // Calculate distances if user location is available
      List<Landmark> landmarksWithDistances = landmarks;
      if (_userPosition != null) {
        landmarksWithDistances = landmarks.map((landmark) {
          return _calculateDistance(landmark);
        }).toList();
      }

      if (!mounted) return;

      setState(() {
        _apiLandmarks = landmarksWithDistances;
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

  Landmark _calculateDistance(Landmark landmark) {
    if (_userPosition == null) return landmark;

    try {
      final distanceInMeters = Geolocator.distanceBetween(
        _userPosition!.latitude,
        _userPosition!.longitude,
        landmark.latitude,
        landmark.longitude,
      );

      // Convert to kilometers and return new landmark with distance
      return landmark.copyWith(distance: distanceInMeters / 1000);
    } catch (e) {
      debugPrint('Distance calculation error for ${landmark.name}: $e');
      return landmark;
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
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
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
          borderRadius: BorderRadius.circular(16),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image with badges overlay
              Stack(
                children: [
                  // Image
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    child: landmark.iconUrl != null
                        ? Image.network(
                            landmark.iconUrl!,
                            width: double.infinity,
                            height: 180,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  width: double.infinity,
                                  height: 180,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        AppColors.primary.withOpacity(0.6),
                                        AppColors.darkBlue.withOpacity(0.4),
                                      ],
                                    ),
                                  ),
                                  child: Icon(
                                    _getCategoryIcon(landmark.category),
                                    color: AppColors.white,
                                    size: 60,
                                  ),
                                ),
                          )
                        : Container(
                            width: double.infinity,
                            height: 180,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppColors.primary.withOpacity(0.6),
                                  AppColors.darkBlue.withOpacity(0.4),
                                ],
                              ),
                            ),
                            child: Icon(
                              _getCategoryIcon(landmark.category),
                              color: AppColors.white,
                              size: 60,
                            ),
                          ),
                  ),
                  // Badges overlay
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Row(
                      children: [
                        // Category badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            landmark.categoryDisplayName.toUpperCase(),
                            style: GoogleFonts.slackey(
                              fontSize: 10,
                              color: AppColors.darkBlue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (landmark.isFeatured) ...[
                          const SizedBox(width: 8),
                          // Featured badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star,
                                  size: 12,
                                  color: AppColors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'FEATURED',
                                  style: GoogleFonts.slackey(
                                    fontSize: 10,
                                    color: AppColors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      landmark.name,
                      style: GoogleFonts.slackey(
                        fontSize: 18,
                        color: AppColors.textPrimary,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (landmark.description != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              landmark.description!,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.gray,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    // Distance and category info side by side
                    Row(
                      children: [
                        // Distance
                        Row(
                          children: [
                            Icon(
                              Icons.directions_walk,
                              size: 18,
                              color: AppColors.darkBlue,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              distanceText,
                              style: GoogleFonts.slackey(
                                fontSize: 14,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 24),
                        // Icon indicator
                        Row(
                          children: [
                            Icon(
                              _getCategoryIcon(landmark.category),
                              size: 18,
                              color: AppColors.darkBlue,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              landmark.categoryDisplayName,
                              style: GoogleFonts.slackey(
                                fontSize: 14,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // View Details Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _showLandmarkPreviewModal(landmark),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: AppColors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'View Details',
                              style: GoogleFonts.slackey(
                                fontSize: 14,
                                color: AppColors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.arrow_forward,
                              size: 18,
                              color: AppColors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show landmark preview modal with swipeable images
  void _showLandmarkPreviewModal(Landmark landmark) {
    // Combine icon URL and gallery URLs for the image carousel
    final List<String> allImages = [];
    if (landmark.iconUrl != null && landmark.iconUrl!.isNotEmpty) {
      allImages.add(landmark.iconUrl!);
    }
    allImages.addAll(landmark.galleryUrls);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _LandmarkPreviewModal(
        landmark: landmark,
        images: allImages,
        getCategoryIcon: _getCategoryIcon,
        onGetDirections: () {
          Navigator.pop(context); // Close modal
          // Navigate to search screen with landmark coordinates
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => MainNavigation(
                initialIndex: 1, // Search tab
                landmarkLatitude: landmark.latitude,
                landmarkLongitude: landmark.longitude,
                landmarkName: landmark.name,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Stateful widget for the landmark preview modal
class _LandmarkPreviewModal extends StatefulWidget {
  final Landmark landmark;
  final List<String> images;
  final IconData Function(String) getCategoryIcon;
  final VoidCallback onGetDirections;

  const _LandmarkPreviewModal({
    required this.landmark,
    required this.images,
    required this.getCategoryIcon,
    required this.onGetDirections,
  });

  @override
  State<_LandmarkPreviewModal> createState() => _LandmarkPreviewModalState();
}

class _LandmarkPreviewModalState extends State<_LandmarkPreviewModal> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final landmark = widget.landmark;
    final hasImages = widget.images.isNotEmpty;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.75,
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.gray.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Image carousel
          Expanded(
            flex: 5,
            child: hasImages
                ? Stack(
                    children: [
                      // PageView for swipeable images
                      PageView.builder(
                        controller: _pageController,
                        itemCount: widget.images.length,
                        onPageChanged: (index) {
                          setState(() => _currentPage = index);
                        },
                        itemBuilder: (context, index) {
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.network(
                                widget.images[index],
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return Container(
                                    color: AppColors.lightGray.withOpacity(0.3),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        color: AppColors.darkBlue,
                                        value:
                                            progress.expectedTotalBytes != null
                                            ? progress.cumulativeBytesLoaded /
                                                  progress.expectedTotalBytes!
                                            : null,
                                      ),
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                      color: AppColors.primary.withOpacity(0.3),
                                      child: Icon(
                                        widget.getCategoryIcon(
                                          landmark.category,
                                        ),
                                        size: 60,
                                        color: AppColors.darkBlue,
                                      ),
                                    ),
                              ),
                            ),
                          );
                        },
                      ),

                      // Page indicator dots
                      if (widget.images.length > 1)
                        Positioned(
                          bottom: 16,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              widget.images.length,
                              (index) => AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                width: _currentPage == index ? 24 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _currentPage == index
                                      ? AppColors.darkBlue
                                      : AppColors.gray.withOpacity(0.4),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  )
                : Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Icon(
                        widget.getCategoryIcon(landmark.category),
                        size: 80,
                        color: AppColors.darkBlue,
                      ),
                    ),
                  ),
          ),

          // Content section
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category and featured badges
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          landmark.categoryDisplayName.toUpperCase(),
                          style: GoogleFonts.slackey(
                            fontSize: 10,
                            color: AppColors.darkBlue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (landmark.isFeatured) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star,
                                size: 12,
                                color: AppColors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'FEATURED',
                                style: GoogleFonts.slackey(
                                  fontSize: 10,
                                  color: AppColors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const Spacer(),
                      // Image count indicator
                      if (widget.images.length > 1)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.gray.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.photo_library,
                                size: 14,
                                color: AppColors.gray,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${widget.images.length} photos',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.gray,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Landmark name
                  Text(
                    landmark.name,
                    style: GoogleFonts.slackey(
                      fontSize: 22,
                      color: AppColors.textPrimary,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  if (landmark.description != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            landmark.description!,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.gray,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],

                  const Spacer(),

                  // Get Directions Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: widget.onGetDirections,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.darkBlue,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 2,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.directions, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            'Get Directions',
                            style: GoogleFonts.slackey(
                              fontSize: 16,
                              color: AppColors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
