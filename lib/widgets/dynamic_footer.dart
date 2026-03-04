import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';

class DynamicFooter extends StatefulWidget {
  @override
  _DynamicFooterState createState() => _DynamicFooterState();
}

class _DynamicFooterState extends State<DynamicFooter> {
  Map<String, dynamic> _links = {'quick_links': [], 'support': [], 'community': []};
  List<dynamic> _socials = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchFooterData();
  }

  Future<void> _fetchFooterData() async {
    try {
      final results = await Future.wait([
        ApiService.getFooterLinks(),
        ApiService.getFooterSocials(),
      ]);
      setState(() {
        _links = results[0] as Map<String, dynamic>;
        _socials = results[1] as List<dynamic>;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _loading = false;
        // Fallback mirrors Footer.jsx
        _links = {
          'quick_links': [
            {'title': 'Live Matches', 'route': '/'},
            {'title': 'Upcoming Schedule', 'route': '/schedule'},
            {'title': 'Points Table', 'route': '/points-table'},
          ],
          'support': [
            {'title': 'Contact Us', 'route': '/contact'},
            {'title': 'Share Feedback', 'route': '/feedback'},
            {'title': 'Report Issues', 'route': '/report'},
          ],
          'community': [
            {'title': 'Improvements', 'route': '/improvements'},
            {'title': 'Join Council', 'route': '/join'},
            {'title': 'Sponsorship', 'route': '/sponsorship'},
            {'title': 'User Manual', 'route': '/user-manual'},
            {'title': 'Admin Manual', 'route': '/admin-manual'},
            {'title': 'Console', 'route': '/login'},
          ]
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        border: const Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset('assets/logo.png', height: 40),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SMCC LIVE', style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  Text('Official Cricket Portal', style: GoogleFonts.outfit(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'S Mettur Cricket Council (SMCC) is dedicated to bringing professional-grade cricket scoring and live updates to our community. Experience cricket like never before.',
            style: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: 32),
          
          if (_loading)
            const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white24)))
          else
            Column(
              children: [
                _buildLinkSection('QUICK LINKS', _links['quick_links']),
                _buildLinkSection('SUPPORT', _links['support']),
                _buildLinkSection('COMMUNITY', _links['community']),
              ],
            ),

          const SizedBox(height: 32),
          const Divider(color: Colors.white10),
          const SizedBox(height: 24),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _socials.map((s) => _socialIcon(s['platform'], s['url'])).toList(),
          ),
          
          const SizedBox(height: 32),
          Center(
            child: Column(
              children: [
                Text('© ${DateTime.now().year} SMCC LIVE. ALL RIGHTS RESERVED.', 
                  style: GoogleFonts.outfit(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                const SizedBox(height: 8),
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.outfit(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold),
                    children: [
                      const TextSpan(text: 'DESIGNED & DEVELOPED BY '),
                      TextSpan(text: 'DHANUSH THANGARAJ', style: GoogleFonts.outfit(color: Colors.blueAccent, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkSection(String title, dynamic links) {
    if (links == null || (links as List).isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.outfit(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          const SizedBox(height: 12),
          ... (links).map((l) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => _handleNavigation(l['route']),
              child: Text(l['title'], style: GoogleFonts.outfit(color: Colors.grey.shade300, fontSize: 13, fontWeight: FontWeight.w500)),
            ),
          )).toList(),
        ],
      ),
    );
  }

  void _handleNavigation(String route) {
     if (route == '/login') {
        Navigator.pushNamed(context, '/login');
     } else if (route == '/user-manual') {
        launchUrl(Uri.parse('https://smcc-web.vercel.app/user-manual'), mode: LaunchMode.externalApplication);
     } else if (route == '/admin-manual') {
        launchUrl(Uri.parse('https://smcc-web.vercel.app/admin-manual'), mode: LaunchMode.externalApplication);
     }
  }

  Widget _socialIcon(String platform, String url) {
    IconData icon = Icons.link;
    final p = platform.toLowerCase();
    if (p.contains('facebook')) icon = Icons.facebook;
    if (p.contains('instagram')) icon = Icons.camera_alt;
    if (p.contains('twitter') || p.contains('x')) icon = Icons.close; // Approximate X
    if (p.contains('whatsapp')) icon = Icons.chat;
    if (p.contains('youtube')) icon = Icons.play_circle_fill;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: InkWell(
        onTap: () => launchUrl(Uri.parse(url)),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white70, size: 20),
        ),
      ),
    );
  }
}
