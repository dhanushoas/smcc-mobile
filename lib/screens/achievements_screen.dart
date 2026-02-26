import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AchievementsScreen extends StatelessWidget {
  final List<Map<String, dynamic>> achievements = [
    {
      "title": "District Champions 2024",
      "year": "2024",
      "description": "Winner of the SMCC LIVE Inter-District Cricket Championship.",
      "icon": Icons.emoji_events,
      "color": Colors.orange
    },
    {
      "title": "Best Organized Council",
      "year": "2023",
      "description": "Awarded by the State Sports Authority for excellence in sports management.",
      "icon": Icons.workspace_premium,
      "color": Colors.blue
    },
    {
      "title": "Fair Play Award",
      "year": "2023",
      "description": "Recognized for maintaining high standards of sportsmanship across all tournaments.",
      "icon": Icons.verified_user,
      "color": Colors.green
    },
    {
      "title": "Community Outreach",
      "year": "2022",
      "description": "Successfully trained over 500+ young cricketers under our development program.",
      "icon": Icons.groups,
      "color": Colors.cyan
    }
  ];

  @override
  Widget build(BuildContext context) {
    final primaryBlue = Color(0xFF2563EB);
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: Text('ACHIEVEMENTS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: primaryBlue, fontSize: 16, letterSpacing: 2)),
        iconTheme: IconThemeData(color: primaryBlue),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Center(
              child: Column(
                children: [
                  Text(
                    'OUR ACHIEVEMENTS',
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: primaryBlue,
                      letterSpacing: 2,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Celebrating years of excellence, passion, and sportsmanship.',
                    style: GoogleFonts.outfit(color: Colors.grey, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            SizedBox(height: 30),
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: achievements.length,
              itemBuilder: (context, index) {
                final ach = achievements[index];
                return _buildAchievementCard(context, ach);
              },
            ),
            SizedBox(height: 30),
            Container(
              padding: EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.05),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.withOpacity(0.2), style: BorderStyle.solid),
              ),
              child: Column(
                children: [
                  Text(
                    'MANY MORE TO COME',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'We are committed to pushing boundaries and achieving new heights in the world of cricket.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementCard(BuildContext context, Map<String, dynamic> ach) {
    return Card(
      margin: EdgeInsets.only(bottom: 20),
      elevation: 4,
      shadowColor: Colors.black26,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 100,
              color: Color(0xFF1E293B),
              child: Center(
                child: Icon(ach['icon'], color: ach['color'], size: 48),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            ach['title'].toString().toUpperCase(),
                            style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: Color(0xFF2563EB), borderRadius: BorderRadius.circular(20)),
                          child: Text(ach['year'], style: GoogleFonts.outfit(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Text(
                      ach['description'],
                      style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12),
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
}
