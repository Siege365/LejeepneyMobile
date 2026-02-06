import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/ticket_notification_service.dart';
import '../../utils/page_transitions.dart';
import '../auth/login_screen.dart';
import 'recent_activity_screen.dart';
import 'notifications_screen.dart';
import 'settings_screen.dart';
import 'about_screen.dart';
import 'report_feedback_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  UserModel? _user;
  bool _isLoading = true;
  bool _isLoggingOut = false;
  int _unreadNotificationCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _initNotificationBadge();
  }

  void _initNotificationBadge() {
    // Listen for unread count changes
    TicketNotificationService.instance.addUnreadCountListener(
      _onUnreadCountChanged,
    );
    // Fetch initial count
    TicketNotificationService.instance.fetchUnreadCount();
  }

  void _onUnreadCountChanged(int count) {
    if (mounted) {
      setState(() => _unreadNotificationCount = count);
    }
  }

  @override
  void dispose() {
    TicketNotificationService.instance.removeUnreadCountListener(
      _onUnreadCountChanged,
    );
    super.dispose();
  }

  Future<void> _loadUser() async {
    setState(() => _isLoading = true);

    try {
      // First try cached user
      final cachedUser = await _authService.getCachedUser();
      if (cachedUser != null && mounted) {
        setState(() => _user = cachedUser);
      }

      // Then verify with server
      final user = await _authService.getCurrentUser();
      if (mounted) {
        setState(() {
          _user = user;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _logout() async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoggingOut = true);

    try {
      await _authService.logout();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          FadeRoute(page: const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoggingOut = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logout failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = _user != null;

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: _isLoggingOut
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.white),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    // Title
                    Text(
                      'Profile',
                      style: GoogleFonts.slackey(
                        fontSize: 28,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Profile Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Avatar
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              shape: BoxShape.circle,
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(
                                    color: AppColors.darkBlue,
                                  )
                                : const Icon(
                                    Icons.person,
                                    size: 50,
                                    color: AppColors.darkBlue,
                                  ),
                          ),
                          const SizedBox(height: 16),
                          // Name
                          Text(
                            isLoggedIn ? _user!.name : 'Guest User',
                            style: GoogleFonts.slackey(
                              fontSize: 20,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isLoggedIn ? _user!.email : 'Not logged in',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.gray,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Login/Logout Button
                          if (!isLoggedIn)
                            SizedBox(
                              width: double.infinity,
                              height: 45,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.pushReplacement(
                                    context,
                                    FadeRoute(page: const LoginScreen()),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.darkBlue,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                ),
                                child: const Text(
                                  'Login / Sign Up',
                                  style: TextStyle(
                                    color: AppColors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Settings Options
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _buildSettingItem(
                            icon: Icons.history,
                            title: 'Recent Activity',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const RecentActivityScreen(),
                                ),
                              );
                            },
                          ),
                          _buildDivider(),
                          _buildSettingItem(
                            icon: Icons.notifications_outlined,
                            title: 'Notifications',
                            badge: _unreadNotificationCount > 0
                                ? _unreadNotificationCount
                                : null,
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const NotificationsScreen(),
                                ),
                              );
                              // Refresh count when returning from notifications
                              TicketNotificationService.instance
                                  .fetchUnreadCount();
                            },
                          ),
                          _buildDivider(),
                          _buildSettingItem(
                            icon: Icons.settings_outlined,
                            title: 'Settings',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const SettingsScreen(),
                                ),
                              );
                            },
                          ),
                          _buildDivider(),
                          _buildSettingItem(
                            icon: Icons.feedback_outlined,
                            title: 'Report & Feedback',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const ReportFeedbackScreen(),
                                ),
                              );
                            },
                          ),
                          _buildDivider(),
                          _buildSettingItem(
                            icon: Icons.info_outline,
                            title: 'About',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const AboutScreen(),
                                ),
                              );
                            },
                          ),
                          if (isLoggedIn) ...[
                            _buildDivider(),
                            _buildSettingItem(
                              icon: Icons.logout,
                              title: 'Log Out',
                              onTap: _logout,
                              isDestructive: true,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
    int? badge,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? AppColors.error : AppColors.darkBlue,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          color: isDestructive ? AppColors.error : AppColors.textPrimary,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                badge > 99 ? '99+' : badge.toString(),
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.gray),
        ],
      ),
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return const Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: AppColors.lightGray,
    );
  }
}
