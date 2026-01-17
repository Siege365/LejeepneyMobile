import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';

class LandmarksScreen extends StatefulWidget {
  const LandmarksScreen({super.key});

  @override
  State<LandmarksScreen> createState() => _LandmarksScreenState();
}

class _LandmarksScreenState extends State<LandmarksScreen> {
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _categories = [
    'All',
    'Downtown',
    'Malls',
    'Schools',
    'Hospitals',
    'Transport',
  ];

  final List<Map<String, dynamic>> _landmarks = [
    // Downtown / City Center
    {
      'name': 'San Pedro Cathedral',
      'category': 'Downtown',
      'icon': Icons.church,
      'area': 'San Pedro Street',
      'distance': '1.2 km',
    },
    {
      'name': 'City Hall of Davao',
      'category': 'Downtown',
      'icon': Icons.account_balance,
      'area': 'San Pedro',
      'distance': '1.5 km',
    },
    {
      'name': 'Rizal Park',
      'category': 'Downtown',
      'icon': Icons.park,
      'area': 'Downtown',
      'distance': '1.3 km',
    },
    {
      'name': 'People\'s Park',
      'category': 'Downtown',
      'icon': Icons.nature_people,
      'area': 'Palma Gil Street',
      'distance': '1.4 km',
    },
    {
      'name': 'Ateneo de Davao University',
      'category': 'Downtown',
      'icon': Icons.school,
      'area': 'Jacinto / Roxas Ave',
      'distance': '2.0 km',
    },
    {
      'name': 'Roxas Avenue Night Market',
      'category': 'Downtown',
      'icon': Icons.nightlife,
      'area': 'Roxas Avenue',
      'distance': '1.8 km',
    },
    {
      'name': 'Claveria Street',
      'category': 'Downtown',
      'icon': Icons.location_city,
      'area': 'Downtown',
      'distance': '1.6 km',
    },
    {
      'name': 'Bangkerohan Public Market',
      'category': 'Downtown',
      'icon': Icons.storefront,
      'area': 'Bankerohan',
      'distance': '2.2 km',
    },
    {
      'name': 'Agdao Public Market',
      'category': 'Downtown',
      'icon': Icons.store,
      'area': 'Agdao',
      'distance': '3.5 km',
    },
    {
      'name': 'Uyanguren',
      'category': 'Downtown',
      'icon': Icons.streetview,
      'area': 'Downtown',
      'distance': '1.7 km',
    },
    {
      'name': 'Quimpo Boulevard',
      'category': 'Downtown',
      'icon': Icons.route,
      'area': 'Matina',
      'distance': '4.0 km',
    },
    {
      'name': 'Ecoland Terminal',
      'category': 'Downtown',
      'icon': Icons.directions_bus,
      'area': 'Ecoland',
      'distance': '5.2 km',
    },
    {
      'name': 'SM City Davao',
      'category': 'Downtown',
      'icon': Icons.shopping_bag,
      'area': 'Ecoland',
      'distance': '5.5 km',
    },

    // Malls & Commercial
    {
      'name': 'Gaisano Mall of Davao',
      'category': 'Malls',
      'icon': Icons.local_mall,
      'area': 'Ilustre Street',
      'distance': '1.9 km',
    },
    {
      'name': 'Abreeza Mall',
      'category': 'Malls',
      'icon': Icons.shopping_cart,
      'area': 'JP Laurel Avenue',
      'distance': '3.2 km',
    },
    {
      'name': 'Victoria Plaza',
      'category': 'Malls',
      'icon': Icons.business,
      'area': 'Bankerohan',
      'distance': '2.3 km',
    },
    {
      'name': 'SM Lanang Premier',
      'category': 'Malls',
      'icon': Icons.storefront,
      'area': 'Lanang',
      'distance': '6.0 km',
    },
    {
      'name': 'NCCC Mall Buhangin',
      'category': 'Malls',
      'icon': Icons.store,
      'area': 'Buhangin',
      'distance': '4.5 km',
    },
    {
      'name': 'NCCC Mall Uyanguren',
      'category': 'Malls',
      'icon': Icons.store,
      'area': 'Uyanguren',
      'distance': '1.8 km',
    },
    {
      'name': 'Aldevinco Shopping Center',
      'category': 'Malls',
      'icon': Icons.shopping_basket,
      'area': 'CM Recto Street',
      'distance': '1.4 km',
    },

    // Schools & Institutions
    {
      'name': 'University of Mindanao',
      'category': 'Schools',
      'icon': Icons.school,
      'area': 'Bolton / Matina',
      'distance': '3.8 km',
    },
    {
      'name': 'San Pedro College',
      'category': 'Schools',
      'icon': Icons.school,
      'area': 'San Pedro',
      'distance': '1.5 km',
    },
    {
      'name': 'USeP',
      'category': 'Schools',
      'icon': Icons.school,
      'area': 'Obrero / Mintal',
      'distance': '4.2 km',
    },
    {
      'name': 'Holy Cross of Davao College',
      'category': 'Schools',
      'icon': Icons.school,
      'area': 'Sta. Ana Avenue',
      'distance': '2.5 km',
    },
    {
      'name': 'Davao Doctors College',
      'category': 'Schools',
      'icon': Icons.school,
      'area': 'Gen. Malvar St.',
      'distance': '1.6 km',
    },

    // Hospitals
    {
      'name': 'Southern Philippines Medical Center',
      'category': 'Hospitals',
      'icon': Icons.local_hospital,
      'area': 'Bajada',
      'distance': '2.8 km',
    },
    {
      'name': 'Davao Doctors Hospital',
      'category': 'Hospitals',
      'icon': Icons.local_hospital,
      'area': 'Gen. Malvar St.',
      'distance': '1.7 km',
    },
    {
      'name': 'San Pedro Hospital',
      'category': 'Hospitals',
      'icon': Icons.local_hospital,
      'area': 'San Pedro',
      'distance': '1.3 km',
    },
    {
      'name': 'Brokenshire Hospital',
      'category': 'Hospitals',
      'icon': Icons.local_hospital,
      'area': 'Madapo Hills',
      'distance': '3.0 km',
    },

    // Transport & Terminals
    {
      'name': 'Ecoland Bus Terminal',
      'category': 'Transport',
      'icon': Icons.directions_bus,
      'area': 'Ecoland',
      'distance': '5.2 km',
    },
    {
      'name': 'Francisco Bangoy Int\'l Airport',
      'category': 'Transport',
      'icon': Icons.flight,
      'area': 'Buhangin',
      'distance': '7.5 km',
    },
  ];

  List<Map<String, dynamic>> get _filteredLandmarks {
    return _landmarks.where((landmark) {
      final matchesCategory =
          _selectedCategory == 'All' ||
          landmark['category'] == _selectedCategory;
      final matchesSearch =
          _searchQuery.isEmpty ||
          (landmark['name'] as String).toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          (landmark['area'] as String).toLowerCase().contains(
            _searchQuery.toLowerCase(),
          );
      return matchesCategory && matchesSearch;
    }).toList();
  }

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
                    : 'Results for "${_searchQuery}"',
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

            // Landmarks List
            Expanded(
              child: _filteredLandmarks.isEmpty
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
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredLandmarks.length,
                      itemBuilder: (context, index) {
                        final landmark = _filteredLandmarks[index];
                        return _buildLandmarkCard(landmark);
                      },
                    ),
            ),
            const SizedBox(height: 80), // Space for bottom nav
          ],
        ),
      ),
    );
  }

  Widget _buildLandmarkCard(Map<String, dynamic> landmark) {
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Navigate to ${landmark['name']}'),
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
                // Icon Container
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    landmark['icon'] as IconData,
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
                        landmark['name'] as String,
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
                              landmark['category'] as String,
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.success,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.location_on,
                            size: 12,
                            color: AppColors.gray,
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              landmark['area'] as String,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.gray,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
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
                            '${landmark['distance']} away',
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
