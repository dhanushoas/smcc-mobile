import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class JoinCouncilScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final primaryBlue = Color(0xFF2563EB);
    
    return Scaffold(
      appBar: AppBar(title: Text('JOIN COUNCIL')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Center(
              child: Column(
                children: [
                  Text(
                    'JOIN THE COUNCIL',
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: primaryBlue,
                      letterSpacing: 2,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Become a vital part of the SMCC LIVE ecosystem.',
                    style: GoogleFonts.outfit(color: Colors.grey, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            SizedBox(height: 32),
            _buildRoleCard(
              context,
              'AS A PLAYER',
              'Register as an official player to participate in league matches, track your stats, and build your profile.',
              [
                'Official player ID and profile',
                'Advanced career stats and rankings',
                'Eligibility for district selections'
              ],
              Icons.person_add,
              primaryBlue,
              primaryBlue.withOpacity(0.1),
              false
            ),
            SizedBox(height: 24),
            _buildRoleCard(
              context,
              'AS AN OFFICIAL',
              'Join as an umpire, scorer, or tournament organizer to help manage the league with professional tools.',
              [
                'Admin dashboard access',
                'Professional training sessions',
                'Be part of decision-making bodies'
              ],
              Icons.shield,
              Colors.white,
              Color(0xFF1E293B),
              true
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleCard(BuildContext context, String title, String desc, List<String> perks, IconData icon, Color accent, Color bg, bool dark) {
    return Card(
      elevation: 8,
      shadowColor: Colors.black12,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(40),
            width: double.infinity,
            color: bg,
            child: Column(
              children: [
                Icon(icon, size: 48, color: accent),
                SizedBox(height: 16),
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    color: dark ? Colors.white : accent,
                    letterSpacing: 1,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  desc,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    color: dark ? Colors.white70 : Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              children: [
                ...perks.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, size: 16, color: dark ? Color(0xFF2563EB) : Colors.green),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          p,
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                )).toList(),
                SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: dark ? Colors.black : Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                    ),
                    child: Text(
                      dark ? 'APPLY FOR OFFICIAL ROLE' : 'REGISTER AS PLAYER',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
