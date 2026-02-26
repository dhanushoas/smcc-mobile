import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SponsorshipScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final primaryBlue = Color(0xFF2563EB);
    
    return Scaffold(
      appBar: AppBar(title: Text('SPONSORSHIP')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Center(
              child: Column(
                children: [
                  Text(
                    'PARTNER WITH SMCC',
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: primaryBlue,
                      letterSpacing: 2,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Empowering local cricket through strategic partnerships.',
                    style: GoogleFonts.outfit(color: Colors.grey, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            SizedBox(height: 32),
            Container(
              padding: EdgeInsets.all(32),
              width: double.infinity,
              decoration: BoxDecoration(
                color: primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: primaryBlue.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  Text('Why Sponsor Us?', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18, color: primaryBlue)),
                  SizedBox(height: 12),
                  Text(
                    'Partnering with SMCC LIVE offers your brand unparalleled visibility among local sports enthusiasts and the wider community.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(color: Colors.grey.shade700, fontSize: 13),
                  ),
                ],
              ),
            ),
            SizedBox(height: 32),
            _buildPlanCard(
              'Tournament Title Sponsor',
              ['Logo on all match graphics', 'Trophy branding', 'Social media mentions'],
              Icons.star,
              Colors.orange
            ),
            SizedBox(height: 20),
            _buildPlanCard(
              'Team Kit Partner',
              ['Logo on player jerseys', 'Live stream presence', 'Match day banners'],
              Icons.style,
              primaryBlue
            ),
            SizedBox(height: 20),
            _buildPlanCard(
              'Digital Platform Partner',
              ['Website banner ads', 'App integration', 'Data insights branding'],
              Icons.devices,
              Colors.cyan
            ),
            SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                  elevation: 8,
                  shadowColor: primaryBlue.withOpacity(0.4),
                ),
                child: Text('DOWNLOAD SPONSORSHIP BROCHURE', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12)),
              ),
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard(String title, List<String> features, IconData icon, Color color) {
    return Card(
      elevation: 4,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 48),
            SizedBox(height: 16),
            Text(title.toUpperCase(), style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14)),
            SizedBox(height: 20),
            ...features.map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, size: 14, color: Colors.grey),
                  SizedBox(width: 8),
                  Expanded(child: Text(f, style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold))),
                ],
              ),
            )).toList(),
            SizedBox(height: 20),
            OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                side: BorderSide(color: color, width: 2),
                minimumSize: Size(double.infinity, 45),
              ),
              child: Text('INQUIRE NOW', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 11, color: color)),
            ),
          ],
        ),
      ),
    );
  }
}
