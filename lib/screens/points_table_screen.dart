import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

class PointsTableScreen extends StatefulWidget {
  @override
  _PointsTableScreenState createState() => _PointsTableScreenState();
}

class _PointsTableScreenState extends State<PointsTableScreen> {
  List<dynamic> stats = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    calculatePoints();
  }

  Future<void> calculatePoints() async {
    try {
      final res = await ApiService.getMatches();
      final completedMatches = res.where((m) => m['status'] == 'completed').toList();
      Map<String, dynamic> teamStats = {};

      for (var m in completedMatches) {
        List innings = m['innings'] ?? [];
        if (innings.length < 2) continue;
        List teams = [m['teamA'], m['teamB']];
        for (var t in teams) {
          if (!teamStats.containsKey(t)) {
            teamStats[t] = {
              'name': t, 'p': 0, 'w': 0, 'l': 0, 'd': 0, 'pts': 0, 
              'runsScored': 0, 'oversFaced': 0.0, 'runsConceded': 0, 'oversBowled': 0.0
            };
          }
          teamStats[t]['p'] += 1;
        }

        dynamic inn1 = innings[0], inn2 = innings[1];
        int runs1 = (inn1['runs'] as num).toInt(), runs2 = (inn2['runs'] as num).toInt();
        String team1 = inn1['team'], team2 = inn2['team'];

        if (runs1 > runs2) { 
          teamStats[team1]['w'] += 1; teamStats[team1]['pts'] += 2; teamStats[team2]['l'] += 1; 
        } else if (runs2 > runs1) { 
          teamStats[team2]['w'] += 1; teamStats[team2]['pts'] += 2; teamStats[team1]['l'] += 1; 
        } else if (innings.length >= 4) {
          // Super Over
          dynamic inn3 = innings[2], inn4 = innings[3];
          int r3 = (inn3['runs'] as num).toInt(), r4 = (inn4['runs'] as num).toInt();
          if (r3 > r4) {
             String wTeam = inn3['team'];
             String lTeam = inn3['team'] == team1 ? team2 : team1;
             teamStats[wTeam]['w'] += 1; teamStats[wTeam]['pts'] += 2; teamStats[lTeam]['l'] += 1;
          } else if (r4 > r3) {
             String wTeam = inn4['team'];
             String lTeam = inn4['team'] == team1 ? team2 : team1;
             teamStats[wTeam]['w'] += 1; teamStats[wTeam]['pts'] += 2; teamStats[lTeam]['l'] += 1;
          } else {
             teamStats[team1]['d'] += 1; teamStats[team1]['pts'] += 1; teamStats[team2]['d'] += 1; teamStats[team2]['pts'] += 1;
          }
        } else { 
          teamStats[team1]['d'] += 1; teamStats[team1]['pts'] += 1; teamStats[team2]['d'] += 1; teamStats[team2]['pts'] += 1; 
        }

        teamStats[team1]['runsScored'] += runs1; teamStats[team1]['oversFaced'] += (inn1['overs'] as num).toDouble();
        teamStats[team1]['runsConceded'] += runs2; teamStats[team1]['oversBowled'] += (inn2['overs'] as num).toDouble();
        teamStats[team2]['runsScored'] += runs2; teamStats[team2]['oversFaced'] += (inn2['overs'] as num).toDouble();
        teamStats[team2]['runsConceded'] += runs1; teamStats[team2]['oversBowled'] += (inn1['overs'] as num).toDouble();
      }

      List result = teamStats.values.map((t) {
        double f = t['oversFaced'] > 0 ? t['runsScored'] / t['oversFaced'] : 0;
        double a = t['oversBowled'] > 0 ? t['runsConceded'] / t['oversBowled'] : 0;
        t['nrr'] = (f - a).toStringAsFixed(3);
        return t;
      }).toList();

      result.sort((a,b) {
        int p = (b['pts'] as int).compareTo(a['pts'] as int);
        return p != 0 ? p : double.parse(b['nrr']).compareTo(double.parse(a['nrr']));
      });

      if (mounted) setState(() { stats = result; isLoading = false; });
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
        title: Text('STANDINGS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: primaryBlue, fontSize: 16, letterSpacing: 1.2)),
      ),
      body: isLoading ? Center(child: CircularProgressIndicator(color: primaryBlue)) : RefreshIndicator(
        onRefresh: calculatePoints,
        color: primaryBlue,
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              SizedBox(height: 20),
              _buildHeader(),
              SizedBox(height: 32),
              _buildStandingsCard(primaryBlue),
              SizedBox(height: 24),
              _buildNRRInfo(primaryBlue),
              SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Text('LEAGUE STATS', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 2)),
        SizedBox(height: 8),
        Text('SMCC PREMIER LEAGUE 2026', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _buildStandingsCard(Color primaryBlue) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: primaryBlue.withOpacity(0.1)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: Offset(0, 10))],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(color: primaryBlue.withOpacity(0.05), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            child: Row(
              children: [
                Icon(Icons.emoji_events_rounded, color: primaryBlue, size: 24),
                SizedBox(width: 12),
                Text('CURRENT STANDINGS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1, color: primaryBlue)),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 24,
              headingRowHeight: 50,
              dataRowHeight: 65,
              columns: [
                _col('POS'), _col('TEAM'), _col('P'), _col('W'), _col('L'), _col('NRR'), _col('PTS'),
              ],
              rows: stats.asMap().entries.map((e) {
                final t = e.value;
                return DataRow(cells: [
                  DataCell(Text((e.key + 1).toString(), style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12))),
                  DataCell(Text(t['name'].toString().toUpperCase(), style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12, color: primaryBlue))),
                  DataCell(_cell(t['p'].toString())),
                  DataCell(_cell(t['w'].toString(), color: Colors.green)),
                  DataCell(_cell(t['l'].toString(), color: Colors.red)),
                  DataCell(_cell(t['nrr'].toString())),
                  DataCell(Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: primaryBlue, borderRadius: BorderRadius.circular(8)),
                    child: Text(t['pts'].toString(), style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
                  )),
                ]);
              }).toList(),
            ),
          ),
          if (stats.isEmpty) Padding(padding: EdgeInsets.all(40), child: Text('No matches completed yet', style: GoogleFonts.outfit(color: Colors.grey, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  DataColumn _col(String l) => DataColumn(label: Text(l, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)));
  Widget _cell(String t, {Color? color}) => Text(t, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: color));

  Widget _buildNRRInfo(Color primaryBlue) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(color: primaryBlue.withOpacity(0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: primaryBlue.withOpacity(0.1))),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: primaryBlue),
          SizedBox(width: 12),
          Expanded(child: Text('NRR: (Runs Scored / Overs Faced) - (Runs Conceded / Overs Bowled)', style: GoogleFonts.outfit(fontSize: 10, color: primaryBlue, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }
}
