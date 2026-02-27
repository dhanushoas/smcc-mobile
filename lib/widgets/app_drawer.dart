import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../screens/home_screen.dart';
import '../screens/schedule_screen.dart';
import '../screens/points_table_screen.dart';
import '../screens/achievements_screen.dart';
import '../screens/interaction_screen.dart';
import '../screens/join_council_screen.dart';
import '../screens/sponsorship_screen.dart';
import '../screens/improvements_screen.dart';
import '../screens/privacy_screen.dart';

class AppDrawer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final primaryBlue = Color(0xFF2563EB);
    
    return Drawer(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryBlue, Color(0xFF059669)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Container(
                     padding: EdgeInsets.all(3),
                     decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                     child: ClipRRect(
                       borderRadius: BorderRadius.circular(30),
                       child: Image.asset('assets/logo.png', height: 60, width: 60),
                     ),
                   ),
                   SizedBox(height: 10),
                   Text(
                     'SMCC LIVE',
                     style: GoogleFonts.outfit(
                       color: Colors.white,
                       fontSize: 24,
                       fontWeight: FontWeight.w900,
                       letterSpacing: 2,
                     ),
                   ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(context, Icons.home_rounded, 'Home', '/', () {
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen()));
                }),
                _buildSectionHeader('QUICK LINKS'),
                _buildDrawerItem(context, Icons.calendar_month_rounded, 'Schedule', '/schedule', () {
                   Navigator.push(context, MaterialPageRoute(builder: (_) => ScheduleScreen()));
                }),
                _buildDrawerItem(context, Icons.leaderboard_rounded, 'Points Table', '/points-table', () {
                   Navigator.push(context, MaterialPageRoute(builder: (_) => PointsTableScreen()));
                }),
                _buildDrawerItem(context, Icons.emoji_events_rounded, 'Achievements', '/achievements', () {
                   Navigator.push(context, MaterialPageRoute(builder: (_) => AchievementsScreen()));
                }),
                
                _buildSectionHeader('SUPPORT'),
                _buildDrawerItem(context, Icons.contact_support_rounded, 'Contact Us', '/contact', () {
                   Navigator.push(context, MaterialPageRoute(builder: (_) => InteractionScreen(type: 'contact', title: 'Contact Us')));
                }),
                _buildDrawerItem(context, Icons.feedback_rounded, 'Share Feedback', '/feedback', () {
                   Navigator.push(context, MaterialPageRoute(builder: (_) => InteractionScreen(type: 'feedback', title: 'Feedback')));
                }),
                _buildDrawerItem(context, Icons.report_problem_rounded, 'Report Issues', '/report', () {
                   Navigator.push(context, MaterialPageRoute(builder: (_) => InteractionScreen(type: 'report', title: 'Report Issue')));
                }),
                _buildDrawerItem(context, Icons.privacy_tip_rounded, 'Privacy Policy', '/privacy', () {
                   Navigator.push(context, MaterialPageRoute(builder: (_) => PrivacyScreen()));
                }),
                
                _buildSectionHeader('COMMUNITY'),
                _buildDrawerItem(context, Icons.star_rounded, 'Improvements', '/improvements', () {
                   Navigator.push(context, MaterialPageRoute(builder: (_) => ImprovementsScreen()));
                }),
                _buildDrawerItem(context, Icons.groups_rounded, 'Join Council', '/join', () {
                   Navigator.push(context, MaterialPageRoute(builder: (_) => JoinCouncilScreen()));
                }),
                _buildDrawerItem(context, Icons.volunteer_activism_rounded, 'Sponsorship', '/sponsorship', () {
                   Navigator.push(context, MaterialPageRoute(builder: (_) => SponsorshipScreen()));
                }),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'v1.0.0 | SMCC LIVE',
              style: GoogleFonts.outfit(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ],
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

  Widget _buildDrawerItem(BuildContext context, IconData icon, String title, String route, VoidCallback onTap) {
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
      contentPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 0),
      visualDensity: VisualDensity.compact,
    );
  }
}
