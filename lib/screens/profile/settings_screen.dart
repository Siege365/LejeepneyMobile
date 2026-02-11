import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../services/settings_service.dart';
import '../../services/localization_service.dart';
import '../../widgets/common/tutorial_overlay.dart';

/// Settings screen — reads/writes via [SettingsService] provider.
/// No local state duplication; every toggle directly updates the service.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final String lang = settings.language;

    // Translation helper
    String t(String key) => LocalizationService.translate(key, lang);

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
          t('settings'),
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
            _buildSectionHeader(t('notifications')),
            const SizedBox(height: 12),
            _buildSettingsCard([
              _buildSwitchTile(
                icon: Icons.notifications_active,
                title: t('push_notifications'),
                subtitle: 'Receive push notifications',
                value: settings.pushNotifications,
                onChanged: (v) => settings.setPushNotifications(v),
              ),
              _buildDivider(),
              _buildSwitchTile(
                icon: Icons.confirmation_number,
                title: t('ticket_updates'),
                subtitle: 'Get notified when tickets are replied',
                value: settings.supportTicketUpdates,
                enabled: settings.pushNotifications,
                onChanged: (v) => settings.setSupportTicketUpdates(v),
              ),
            ]),
            const SizedBox(height: 24),

            // Sound & Vibration
            _buildSectionHeader('Sound & Vibration'),
            const SizedBox(height: 12),
            _buildSettingsCard([
              _buildSwitchTile(
                icon: Icons.volume_up,
                title: t('sound'),
                subtitle: 'Play sound for notifications',
                value: settings.soundEnabled,
                onChanged: (v) => settings.setSoundEnabled(v),
              ),
              _buildDivider(),
              _buildSwitchTile(
                icon: Icons.vibration,
                title: t('vibration'),
                subtitle: 'Vibrate for notifications',
                value: settings.vibration,
                onChanged: (v) {
                  settings.setVibration(v);
                  if (v) settings.triggerVibration();
                },
              ),
            ]),
            const SizedBox(height: 24),

            // General Settings
            _buildSectionHeader(t('general')),
            const SizedBox(height: 12),
            _buildSettingsCard([
              _buildDropdownTile(
                icon: Icons.language,
                title: t('language'),
                value: settings.language,
                items: const ['English', 'Filipino', 'Cebuano'],
                onChanged: (v) {
                  if (v != null) {
                    settings.setLanguage(v);
                    final newT = (String key) =>
                        LocalizationService.translate(key, v);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${newT('language_set_to')} $v'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
              _buildDivider(),
              _buildDropdownTile(
                icon: Icons.straighten,
                title: t('distance_unit'),
                value: t(
                  settings.distanceUnit.toLowerCase(),
                ), // Translate current value
                items: [t('kilometers'), t('miles')],
                onChanged: (v) {
                  if (v != null) {
                    // Map translated value back to English for storage
                    String actualValue = v == t('kilometers')
                        ? 'Kilometers'
                        : 'Miles';
                    settings.setDistanceUnit(actualValue);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${t('distances_shown_in')} $v'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
            ]),
            const SizedBox(height: 24),

            // Location
            _buildSectionHeader(t('privacy')),
            const SizedBox(height: 12),
            _buildSettingsCard([
              _buildSwitchTile(
                icon: Icons.location_on,
                title: t('location_services'),
                subtitle: 'Allow app to access your location',
                value: settings.locationServices,
                onChanged: (v) {
                  settings.setLocationServices(v);
                  if (!v) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Location disabled — distances won\'t be calculated',
                        ),
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
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
                title: t('clear_cache'),
                subtitle: 'Free up storage space',
                onTap: () => _showClearCacheDialog(context, settings),
              ),
              const Divider(height: 1),
              _buildActionTile(
                icon: Icons.play_circle_outline,
                title: 'Replay Tutorial',
                subtitle: 'Watch the app introduction again',
                onTap: () => _replayTutorial(context),
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
      style: GoogleFonts.slackey(
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

  void _showClearCacheDialog(BuildContext context, SettingsService settings) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear Cache'),
        content: const Text(
          'This will clear all cached data including images and route history. Your settings will be preserved. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text('Clearing cache...'),
                    ],
                  ),
                  duration: Duration(seconds: 2),
                ),
              );

              await settings.clearCache();
              await Future.delayed(const Duration(milliseconds: 500));

              if (context.mounted) {
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
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _replayTutorial(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) =>
            TutorialOverlay(onComplete: () => Navigator.of(context).pop()),
      ),
    );
  }
}
