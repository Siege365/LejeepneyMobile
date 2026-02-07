import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/app_colors.dart';
import '../../widgets/common/tutorial_overlay.dart';

/// Screen for general app settings - Industry standard layout
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // General settings
  String _selectedLanguage = 'English';
  String _selectedDistanceUnit = 'Kilometers';
  bool _darkMode = false;

  // Notification settings (moved from notifications page)
  bool _pushNotifications = true;
  bool _routeUpdates = true;
  bool _fareChanges = true;
  bool _supportTicketUpdates = true;
  bool _promotions = false;
  bool _soundEnabled = true;
  bool _vibration = true;

  // Data & Network settings
  bool _offlineMode = false;
  bool _dataOptimization = true;
  bool _locationServices = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pushNotifications = prefs.getBool('push_notifications') ?? true;
      _routeUpdates = prefs.getBool('route_updates') ?? true;
      _fareChanges = prefs.getBool('fare_changes') ?? true;
      _supportTicketUpdates = prefs.getBool('support_ticket_updates') ?? true;
      _promotions = prefs.getBool('promotions') ?? false;
      _soundEnabled = prefs.getBool('sound_enabled') ?? true;
      _vibration = prefs.getBool('vibration') ?? true;
      _darkMode = prefs.getBool('dark_mode') ?? false;
      _offlineMode = prefs.getBool('offline_mode') ?? false;
      _dataOptimization = prefs.getBool('data_optimization') ?? true;
      _locationServices = prefs.getBool('location_services') ?? true;
    });
  }

  Future<void> _saveSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

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
            // NOTIFICATIONS SECTION (Moved from Notifications page)
            _buildSectionHeader('Notifications'),
            const SizedBox(height: 12),
            _buildSettingsCard([
              _buildSwitchTile(
                icon: Icons.notifications_active,
                title: 'Push Notifications',
                subtitle: 'Receive push notifications',
                value: _pushNotifications,
                onChanged: (value) {
                  setState(() => _pushNotifications = value);
                  _saveSetting('push_notifications', value);
                },
              ),
              _buildDivider(),
              _buildSwitchTile(
                icon: Icons.route,
                title: 'Route Updates',
                subtitle: 'Get notified about route changes',
                value: _routeUpdates,
                enabled: _pushNotifications,
                onChanged: (value) {
                  setState(() => _routeUpdates = value);
                  _saveSetting('route_updates', value);
                },
              ),
              _buildDivider(),
              _buildSwitchTile(
                icon: Icons.attach_money,
                title: 'Fare Changes',
                subtitle: 'Notifications about fare updates',
                value: _fareChanges,
                enabled: _pushNotifications,
                onChanged: (value) {
                  setState(() => _fareChanges = value);
                  _saveSetting('fare_changes', value);
                },
              ),
              _buildDivider(),
              _buildSwitchTile(
                icon: Icons.confirmation_number,
                title: 'Support Ticket Updates',
                subtitle: 'Get notified when tickets are replied',
                value: _supportTicketUpdates,
                enabled: _pushNotifications,
                onChanged: (value) {
                  setState(() => _supportTicketUpdates = value);
                  _saveSetting('support_ticket_updates', value);
                },
              ),
              _buildDivider(),
              _buildSwitchTile(
                icon: Icons.local_offer,
                title: 'Promotions',
                subtitle: 'Receive promotional messages',
                value: _promotions,
                enabled: _pushNotifications,
                onChanged: (value) {
                  setState(() => _promotions = value);
                  _saveSetting('promotions', value);
                },
              ),
            ]),
            const SizedBox(height: 24),

            // Sound & Vibration
            _buildSectionHeader('Sound & Vibration'),
            const SizedBox(height: 12),
            _buildSettingsCard([
              _buildSwitchTile(
                icon: Icons.volume_up,
                title: 'Sound',
                subtitle: 'Play sound for notifications',
                value: _soundEnabled,
                onChanged: (value) {
                  setState(() => _soundEnabled = value);
                  _saveSetting('sound_enabled', value);
                },
              ),
              _buildDivider(),
              _buildSwitchTile(
                icon: Icons.vibration,
                title: 'Vibration',
                subtitle: 'Vibrate for notifications',
                value: _vibration,
                onChanged: (value) {
                  setState(() => _vibration = value);
                  _saveSetting('vibration', value);
                },
              ),
            ]),
            const SizedBox(height: 24),

            // General Settings
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

            // Display
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
                  _saveSetting('dark_mode', value);
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

            // Data & Network
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
                  _saveSetting('offline_mode', value);
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
                  _saveSetting('data_optimization', value);
                },
              ),
            ]),
            const SizedBox(height: 24),

            // Location
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
                  _saveSetting('location_services', value);
                },
              ),
            ]),
            const SizedBox(height: 24),

            // Cache & Storage
            _buildSectionHeader('Cache & Storage'),
            const SizedBox(height: 12),
            _buildSettingsCard([
              _buildActionTile(
                icon: Icons.cleaning_services,
                title: 'Clear Cache',
                subtitle: 'Free up storage space',
                onTap: _showClearCacheDialog,
              ),
              const Divider(height: 1),
              _buildActionTile(
                icon: Icons.play_circle_outline,
                title: 'Replay Tutorial',
                subtitle: 'Watch the app introduction again',
                onTap: _replayTutorial,
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
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: enabled
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: enabled ? AppColors.darkBlue : Colors.grey.shade400,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: enabled ? Colors.black87 : Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: enabled
                        ? Colors.grey.shade600
                        : Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: enabled ? onChanged : null,
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
                  backgroundColor: AppColors.success,
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

  void _replayTutorial() {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) =>
            TutorialOverlay(onComplete: () => Navigator.of(context).pop()),
      ),
    );
  }
}
