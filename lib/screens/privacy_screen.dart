import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PrivacyScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final primaryBlue = Color(0xFF2563EB);
    
    return Scaffold(
      appBar: AppBar(title: Text('PRIVACY POLICY')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            Center(
              child: Column(
                children: [
                  Text(
                    'PRIVACY POLICY',
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: primaryBlue,
                      letterSpacing: 2,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'LAST UPDATED: FEBRUARY 2026',
                    style: GoogleFonts.outfit(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                ],
              ),
            ),
            SizedBox(height: 32),
            Card(
              elevation: 4,
              shadowColor: Colors.black12,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSection(primaryBlue, '1. Data Collection', 'We collect information you provide directly to us when you create an account, participate in tournaments, or communicate with us. This includes your name, email, and performance stats.'),
                    SizedBox(height: 32),
                    _buildSection(primaryBlue, '2. Use of Information', 'We use the information we collect to operate, maintain, and provide the features of the SMCC platform, including live scoring, rankings, and community updates.'),
                    SizedBox(height: 32),
                    _buildSection(primaryBlue, '3. Data Sharing', 'SMCC does not sell your personal data. Player stats and match performances are public by nature as part of the sports platform experience.'),
                    SizedBox(height: 32),
                    _buildSection(primaryBlue, '4. Security', 'We implement industry-standard security measures to protect your data. However, no method of transmission over the Internet is 100% secure.'),
                    SizedBox(height: 32),
                    Divider(),
                    SizedBox(height: 16),
                    Center(
                      child: Text(
                        'For any privacy-related queries, please contact privacy@smcc-mettur.org',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(Color color, String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(), style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14, color: color, letterSpacing: 1)),
        SizedBox(height: 12),
        Text(content, style: GoogleFonts.outfit(color: Colors.grey.shade700, fontSize: 12, height: 1.6)),
      ],
    );
  }
}
