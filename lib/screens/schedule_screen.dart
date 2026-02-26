import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';

class ScheduleScreen extends StatefulWidget {
  @override
  _ScheduleScreenState createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  List<dynamic> matches = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchMatches();
  }

  Future<void> fetchMatches() async {
    try {
      final res = await ApiService.getMatches();
      if (mounted) {
        setState(() {
          matches = res.where((m) => m['status'] == 'upcoming').toList();
          isLoading = false;
        });
      }
    } catch (_) { if (mounted) setState(() => isLoading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final primaryBlue = Color(0xFF2563EB);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: primaryBlue, size: 20), onPressed: () => Navigator.pop(context)),
        title: Text('MATCH SCHEDULE', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: primaryBlue, fontSize: 16, letterSpacing: 1.2)),
      ),
      body: isLoading ? Center(child: CircularProgressIndicator(color: primaryBlue)) : RefreshIndicator(
        onRefresh: fetchMatches,
        color: primaryBlue,
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              SizedBox(height: 20),
              _buildHeader(primaryBlue),
              SizedBox(height: 32),
              if (matches.isEmpty) _buildEmptyState(primaryBlue)
              else ...matches.map((m) => _buildScheduleCard(m, primaryBlue)).toList(),
              SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Color primaryBlue) {
    return Column(
      children: [
        Text('UPCOMING FIXTURES', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 2)),
        SizedBox(height: 12),
        Text("DON'T MISS THE ACTION. MARK YOUR CALENDARS!", textAlign: TextAlign.center, style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildEmptyState(Color primaryBlue) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(40),
      decoration: BoxDecoration(color: primaryBlue.withOpacity(0.03), borderRadius: BorderRadius.circular(24)),
      child: Column(
        children: [
          Icon(Icons.calendar_today_rounded, size: 48, color: primaryBlue.withOpacity(0.2)),
          SizedBox(height: 24),
          Text('NO UPCOMING MATCHES', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14)),
          SizedBox(height: 8),
          Text('Stay tuned for future schedule updates.', style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildScheduleCard(dynamic match, Color primary) {
    DateTime dt = DateTime.parse(match['date']);
    String d = DateFormat('EEE, MMM d').format(dt).toUpperCase();
    String t = DateFormat('hh:mm a').format(dt).toUpperCase();

    return Container(
      margin: EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: primary.withOpacity(0.1)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: Offset(0, 10))],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            decoration: BoxDecoration(color: primary.withOpacity(0.05), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(match['series']?.toUpperCase() ?? 'SMCC LEAGUE', style: GoogleFonts.outfit(color: primary, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5)),
                Row(
                  children: [
                    Icon(Icons.location_on_rounded, size: 12, color: Colors.grey),
                    SizedBox(width: 4),
                    Text(match['venue']?.toUpperCase() ?? 'TBD', style: GoogleFonts.outfit(color: Colors.grey, fontWeight: FontWeight.w900, fontSize: 9)),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: Text(match['teamA'].toUpperCase(), textAlign: TextAlign.center, style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 15))),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(100)),
                      child: Text('VS', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10)),
                    ),
                    Expanded(child: Text(match['teamB'].toUpperCase(), textAlign: TextAlign.center, style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 15))),
                  ],
                ),
                SizedBox(height: 24),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.grey.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _info(d, 'DATE'),
                      Container(width: 1, height: 20, color: Colors.grey.withOpacity(0.2)),
                      _info(t, 'TIME'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: Color(0xFF1E293B), borderRadius: BorderRadius.vertical(bottom: Radius.circular(24))),
            child: Text('${match['totalOvers']} OVERS FORMAT', textAlign: TextAlign.center, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 9, letterSpacing: 2)),
          ),
        ],
      ),
    );
  }

  Widget _info(String v, String l) => Column(children: [
    Text(l, style: GoogleFonts.outfit(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
    Text(v, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900)),
  ]);
}
