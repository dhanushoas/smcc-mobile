import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';

class DynamicFooter extends StatefulWidget {
  @override
  _DynamicFooterState createState() => _DynamicFooterState();
}

class _DynamicFooterState extends State<DynamicFooter> {
  List<dynamic> _links = [];
  List<dynamic> _socials = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchFooterData();
  }

  Future<void> _fetchFooterData() async {
    try {
      final linksData = await ApiService.getMatches(); // Placeholder for getFooterLinks
      // For now, mirroring the web logic - we'll add getFooterLinks to api_service
      setState(() {
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SMCC LIVE',
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 2),
          ),
          const SizedBox(height: 8),
          Text(
            'The complete cricket scoring ecosystem.',
            style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 32),
          // Links sections would go here based on API data
          const Divider(color: Colors.white10),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('© 2026 SMCC', style: GoogleFonts.outfit(color: Colors.grey, fontSize: 10)),
              Row(
                children: [
                  _socialIcon(Icons.facebook),
                  _socialIcon(Icons.camera_alt),
                  _socialIcon(Icons.alternate_email),
                ],
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _socialIcon(IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Icon(icon, color: Colors.grey, size: 18),
    );
  }
}
