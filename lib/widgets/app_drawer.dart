import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/settings_provider.dart';
import '../screens/home_screen.dart';
import '../screens/schedule_screen.dart';
import '../screens/points_table_screen.dart';
import '../screens/achievements_screen.dart';
import '../screens/contact_screen.dart';
import '../screens/feedback_screen.dart';
import '../screens/report_screen.dart';
import '../screens/privacy_screen.dart';
import '../screens/join_council_screen.dart';
import '../screens/sponsorship_screen.dart';
import '../screens/improvements_screen.dart';
import '../screens/admin/admin_login_screen.dart';
import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/admin/admin_scoring_screen.dart';

class AppDrawer extends StatefulWidget {
  @override
  _AppDrawerState createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final admin = await AuthService.isAdmin();
    if (mounted) setState(() => _isAdmin = admin);
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final primaryBlue = Color(0xFF2563EB);
    
    return Drawer(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          _buildHeader(primaryBlue),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(context, Icons.home_rounded, 'Home', () {
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen()));
                }),
                
                if (_isAdmin) ...[
                  _buildSectionHeader('ADMINISTRATION'),
                  _buildDrawerItem(context, Icons.dashboard_rounded, 'Admin Console', () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => AdminDashboardScreen()));
                  }),
                  _buildDrawerItem(context, Icons.logout_rounded, 'Logout', () async {
                    await AuthService.logout();
                    if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen()));
                  }),
                ] else ...[
                  _buildSectionHeader('LOGIN'),
                  _buildDrawerItem(context, Icons.admin_panel_settings_rounded, 'Admin Login', () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => AdminLoginScreen()));
                  }),
                ],

                _buildSectionHeader('QUICK LINKS'),
                _buildDrawerItem(context, Icons.calendar_month_rounded, 'Schedule', () {
                   Navigator.push(context, MaterialPageRoute(builder: (_) => ScheduleScreen()));
                }),
                _buildDrawerItem(context, Icons.leaderboard_rounded, 'Points Table', () {
                   Navigator.push(context, MaterialPageRoute(builder: (_) => PointsTableScreen()));
                }),
                _buildDrawerItem(context, Icons.emoji_events_rounded, 'Achievements', () {
                   Navigator.push(context, MaterialPageRoute(builder: (_) => AchievementsScreen()));
                }),
                
                _buildSectionHeader('SUPPORT'),
                _buildDrawerItem(context, Icons.contact_support_rounded, 'Contact Us', () {
                   Navigator.push(context, MaterialPageRoute(builder: (_) => ContactScreen()));
                }),
                _buildDrawerItem(context, Icons.feedback_rounded, 'Share Feedback', () {
                   Navigator.push(context, MaterialPageRoute(builder: (_) => FeedbackScreen()));
                }),
                _buildDrawerItem(context, Icons.report_problem_rounded, 'Report Issues', () {
                   Navigator.push(context, MaterialPageRoute(builder: (_) => ReportScreen()));
                }),
                _buildDrawerItem(context, Icons.privacy_tip_rounded, 'Privacy Policy', () {
                   Navigator.push(context, MaterialPageRoute(builder: (_) => PrivacyScreen()));
                }),
                
                _buildSectionHeader('COMMUNITY'),
                _buildDrawerItem(context, Icons.star_rounded, 'Improvements', () {
                   Navigator.push(context, MaterialPageRoute(builder: (_) => ImprovementsScreen()));
                }),
                _buildDrawerItem(context, Icons.groups_rounded, 'Join Council', () {
                   Navigator.push(context, MaterialPageRoute(builder: (_) => JoinCouncilScreen()));
                }),
                _buildDrawerItem(context, Icons.volunteer_activism_rounded, 'Sponsorship', () {
                   Navigator.push(context, MaterialPageRoute(builder: (_) => SponsorshipScreen()));
                }),
                _buildDrawerItem(context, Icons.description_rounded, 'User Manual', () {
                   launchUrl(Uri.parse('https://smcc-web.vercel.app/user-manual'), mode: LaunchMode.externalApplication);
                }),
                _buildDrawerItem(context, Icons.admin_panel_settings_rounded, 'Admin Manual', () {
                   launchUrl(Uri.parse('https://smcc-web.vercel.app/admin-manual'), mode: LaunchMode.externalApplication);
                }),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'v1.1.0 | SMCC LIVE',
              style: GoogleFonts.outfit(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(Color primary) {
    return DrawerHeader(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [primary, const Color(0xFF059669)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: ClipRRect(borderRadius: BorderRadius.circular(30), child: Image.asset('assets/logo.png', height: 60, width: 60)),
            ),
            const SizedBox(height: 10),
            Text('SMCC LIVE', style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          color: Color(0xFF2563EB),
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildDrawerItem(BuildContext context, IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary.withOpacity(0.8)),
      title: Text(
        title,
        style: GoogleFonts.outfit(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      visualDensity: VisualDensity.compact,
    );
  }
}
