import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:url_launcher/url_launcher.dart';

class AppFooter extends StatefulWidget {
  @override
  _AppFooterState createState() => _AppFooterState();
}

class _AppFooterState extends State<AppFooter> {
  bool _isLoading = true;
  Map<String, List<dynamic>> _links = {'quick_links': [], 'support': [], 'community': []};
  List<dynamic> _socials = [];

  @override
  void initState() {
    super.initState();
    _fetchDynamicFooter();
  }

  Future<void> _fetchDynamicFooter() async {
    final apiUrl = dotenv.env['API_URL'] ?? 'https://smcc-backend.onrender.com';
    try {
      final linksRes = await http.get(Uri.parse('$apiUrl/api/footer/links'));
      final socialsRes = await http.get(Uri.parse('$apiUrl/api/footer/socials'));

      if (linksRes.statusCode == 200 && socialsRes.statusCode == 200) {
        final Map<String, dynamic> linksData = json.decode(linksRes.body);
        final List<dynamic> socialsData = json.decode(socialsRes.body);

        setState(() {
          _links = {
            'quick_links': linksData['quick_links'] ?? [],
            'support': linksData['support'] ?? [],
            'community': linksData['community'] ?? []
          };
          _socials = socialsData;
          _isLoading = false;
        });
      } else {
        _useFallback();
      }
    } catch (e) {
      _useFallback();
    }
  }

  void _useFallback() {
    setState(() {
      _links = {
        'quick_links': [{'title': 'LIVE MATCHES', 'route': '/'}, {'title': 'SCHEDULE', 'route': '/schedule'}, {'title': 'POINTS TABLE', 'route': '/points_table'}],
        'support': [{'title': 'CONTACT', 'route': '/contact'}, {'title': 'FEEDBACK', 'route': '/feedback'}, {'title': 'REPORT', 'route': '/report'}],
        'community': [{'title': 'IMPROVEMENTS', 'route': '/improvements'}, {'title': 'JOIN COUNCIL', 'route': '/join'}, {'title': 'SPONSORSHIP', 'route': '/sponsorship'}]
      };
      _isLoading = false;
    });
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    }
  }

  IconData _getSocialIcon(String platform) {
    if (platform.contains('facebook')) return Icons.facebook;
    if (platform.contains('instagram')) return Icons.camera_alt; // Proxy
    if (platform.contains('twitter') || platform.contains('x')) return Icons.close; // Proxy X
    if (platform.contains('whatsapp')) return Icons.phone; // Proxy WhatsApp
    return Icons.link;
  }

  Color _getSocialColor(String platform) {
    if (platform.contains('facebook')) return const Color(0xFF1877F2);
    if (platform.contains('instagram')) return const Color(0xFFE4405F);
    if (platform.contains('twitter') || platform.contains('x')) return Colors.black87;
    if (platform.contains('whatsapp')) return const Color(0xFF25D366);
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final primaryBlue = const Color(0xFF2563EB);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: primaryBlue.withOpacity(0.02),
        border: Border(top: BorderSide(color: primaryBlue.withOpacity(0.05))),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: primaryBlue.withOpacity(0.1))),
                child: ClipOval(child: Image.asset('assets/logo.png', height: 30, width: 30)),
              ),
              const SizedBox(width: 10),
              Text(
                'SMCC LIVE',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: primaryBlue, fontSize: 16, letterSpacing: 1),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'S Mettur Cricket Council (SMCC) is dedicated to bringing professional-grade cricket scoring and live updates to our community. Experience cricket like never before.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(color: Colors.grey, fontSize: 11, height: 1.5),
          ),
          const SizedBox(height: 20),
          
          if (!_isLoading && _socials.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _socials.map((s) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: GestureDetector(
                      onTap: () => _launchUrl(s['url']),
                      child: _socialIconWidget(_getSocialIcon(s['platform']), _getSocialColor(s['platform'])),
                    ),
                  )).toList(),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _socialIconWidget(Icons.facebook, const Color(0xFF1877F2)),
                const SizedBox(width: 12),
                _socialIconWidget(Icons.camera_alt, const Color(0xFFE4405F)),
              ],
            ),
            
          const SizedBox(height: 24),
          
          if (_isLoading)
            const Center(child: CircularProgressIndicator(strokeWidth: 2))
          else ...[
            _buildLinkGroup('QUICK LINKS', _links['quick_links'] ?? []),
            const SizedBox(height: 16),
            _buildLinkGroup('SUPPORT', _links['support'] ?? []),
            const SizedBox(height: 16),
            _buildLinkGroup('COMMUNITY', _links['community'] ?? []),
          ],
          
          const SizedBox(height: 32),
          Divider(color: primaryBlue.withOpacity(0.05)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '© ${DateTime.now().year} SMCC LIVE',
                style: GoogleFonts.outfit(color: Colors.grey.withOpacity(0.8), fontSize: 9, fontWeight: FontWeight.bold),
              ),
              Text(
                'BY DHANUSH THANGARAJ',
                style: GoogleFonts.outfit(color: primaryBlue.withOpacity(0.8), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLinkGroup(String title, List<dynamic> groupLinks) {
    if (groupLinks.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        Text(title, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.blueGrey, letterSpacing: 1.5)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 16,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: groupLinks.map((link) => GestureDetector(
            onTap: () {
              if (link['route'] != null && link['route'].toString().isNotEmpty) {
                 Navigator.pushNamed(context, link['route']);
              }
            },
            child: Text(
              link['title']?.toString().toUpperCase() ?? '',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 10, color: Colors.grey.shade600, letterSpacing: 0.5),
            ),
          )).toList(),
        ),
      ],
    );
  }

  Widget _socialIconWidget(IconData icon, Color color) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Icon(icon, color: Colors.white, size: 16),
    );
  }
}
