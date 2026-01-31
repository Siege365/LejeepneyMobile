import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';

/// Screen to manage notification settings
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  // Notification settings
  bool _pushNotifications = true;
  bool _routeUpdates = true;
  bool _fareChanges = true;
  bool _promotions = false;
  bool _emailNotifications = false;
  bool _soundEnabled = true;
  bool _vibration = true;

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
          'Notifications',
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
            _buildSectionHeader('Push Notifications'),
            const SizedBox(height: 12),
            _buildSettingsCard([
              _buildSwitchTile(
                icon: Icons.notifications_active,
                title: 'Push Notifications',
                subtitle: 'Receive push notifications',
                value: _pushNotifications,
                onChanged: (value) {
                  setState(() => _pushNotifications = value);
                },
              ),
              _buildDivider(),
              _buildSwitchTile(
                icon: Icons.route,
                title: 'Route Updates',
                subtitle: 'Get notified about route changes',
                value: _routeUpdates,
                onChanged: _pushNotifications
                    ? (value) {
                        setState(() => _routeUpdates = value);
                      }
                    : null,
              ),
              _buildDivider(),
              _buildSwitchTile(
                icon: Icons.attach_money,
                title: 'Fare Changes',
                subtitle: 'Notifications about fare updates',
                value: _fareChanges,
                onChanged: _pushNotifications
                    ? (value) {
                        setState(() => _fareChanges = value);
                      }
                    : null,
              ),
              _buildDivider(),
              _buildSwitchTile(
                icon: Icons.local_offer,
                title: 'Promotions',
                subtitle: 'Receive promotional messages',
                value: _promotions,
                onChanged: _pushNotifications
                    ? (value) {
                        setState(() => _promotions = value);
                      }
                    : null,
              ),
            ]),
            const SizedBox(height: 24),
            _buildSectionHeader('Other Notifications'),
            const SizedBox(height: 12),
            _buildSettingsCard([
              _buildSwitchTile(
                icon: Icons.email,
                title: 'Email Notifications',
                subtitle: 'Receive updates via email',
                value: _emailNotifications,
                onChanged: (value) {
                  setState(() => _emailNotifications = value);
                },
              ),
            ]),
            const SizedBox(height: 24),
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

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    final isEnabled = onChanged != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isEnabled
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: isEnabled ? AppColors.darkBlue : Colors.grey.shade400,
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
                    color: isEnabled ? Colors.black87 : Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isEnabled
                        ? Colors.grey.shade600
                        : Colors.grey.shade400,
                  ),
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

  Widget _buildDivider() {
    return const Divider(height: 1, indent: 72, endIndent: 16);
  }
}
