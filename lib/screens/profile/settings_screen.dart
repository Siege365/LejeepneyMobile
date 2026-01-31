import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';

/// Screen for general app settings
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Settings values
  String _selectedLanguage = 'English';
  String _selectedDistanceUnit = 'Kilometers';
  bool _darkMode = false;
  bool _offlineMode = false;
  bool _dataOptimization = true;
  bool _locationServices = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Settings',
          style: GoogleFonts.slackey(
            fontSize: 20,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('General'),
            const SizedBox(height: 12),
            _buildSettingsCard([
              _buildDropdownTile(
                icon: Icons.language,
                title: 'Language',
                value: _selectedLanguage,
                items: ['English', 'Filipino', 'Cebuano'],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedLanguage = value);
                  }
                },
              ),
              _buildDivider(),
              _buildDropdownTile(
                icon: Icons.straighten,
                title: 'Distance Unit',
                value: _selectedDistanceUnit,
                items: ['Kilometers', 'Miles'],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedDistanceUnit = value);
                  }
                },
              ),
            ]),
            const SizedBox(height: 24),
            _buildSectionHeader('Display'),
            const SizedBox(height: 12),
            _buildSettingsCard([
              _buildSwitchTile(
                icon: Icons.dark_mode,
                title: 'Dark Mode',
                subtitle: 'Use dark theme',
                value: _darkMode,
                onChanged: (value) {
                  setState(() => _darkMode = value);
                  // TODO: Implement dark mode
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Dark mode coming soon!'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ]),
            const SizedBox(height: 24),
            _buildSectionHeader('Data & Network'),
            const SizedBox(height: 12),
            _buildSettingsCard([
              _buildSwitchTile(
                icon: Icons.cloud_off,
                title: 'Offline Mode',
                subtitle: 'Use cached data when offline',
                value: _offlineMode,
                onChanged: (value) {
                  setState(() => _offlineMode = value);
                },
              ),
              _buildDivider(),
              _buildSwitchTile(
                icon: Icons.data_saver_on,
                title: 'Data Optimization',
                subtitle: 'Reduce data usage',
                value: _dataOptimization,
                onChanged: (value) {
                  setState(() => _dataOptimization = value);
                },
              ),
            ]),
            const SizedBox(height: 24),
            _buildSectionHeader('Location'),
            const SizedBox(height: 12),
            _buildSettingsCard([
              _buildSwitchTile(
                icon: Icons.location_on,
                title: 'Location Services',
                subtitle: 'Allow app to access your location',
                value: _locationServices,
                onChanged: (value) {
                  setState(() => _locationServices = value);
                },
              ),
            ]),
            const SizedBox(height: 24),
            _buildSectionHeader('Cache & Storage'),
            const SizedBox(height: 12),
            _buildSettingsCard([
              _buildActionTile(
                icon: Icons.cleaning_services,
                title: 'Clear Cache',
                subtitle: 'Free up storage space',
                onTap: () {
                  _showClearCacheDialog();
                },
              ),
            ]),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppColors.darkBlue,
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDropdownTile({
    required IconData icon,
    required String title,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.darkBlue, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<String>(
              value: value,
              items: items.map((item) {
                return DropdownMenuItem(
                  value: item,
                  child: Text(item, style: const TextStyle(fontSize: 13)),
                );
              }).toList(),
              onChanged: onChanged,
              underline: const SizedBox(),
              isDense: true,
              icon: const Icon(Icons.arrow_drop_down, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.darkBlue, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.darkBlue,
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.darkBlue, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, indent: 72, endIndent: 16);
  }

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear Cache'),
        content: const Text(
          'This will clear all cached data including offline maps and route history. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white),
                      SizedBox(width: 8),
                      Text('Cache cleared successfully'),
                    ],
                  ),
                  backgroundColor: Color(0xFF10B981),
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}
