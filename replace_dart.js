const fs = require('fs');
const file = './lib/screens/scorecard_screen.dart';
let content = fs.readFileSync(file, 'utf8');

content = content.replace(
    `  Map<String, dynamic>? _match;
  bool _loading = true;`,
    `  Map<String, dynamic>? _match;
  Map<String, dynamic>? _seriesData;
  bool _loading = true;`
);

content = content.replace(
    `  Future<void> _fetchMatch() async {
    try {
      final data = await ApiService.getMatch(widget.matchId);
      setState(() {
        _match = data;
        _loading = false;
        _setActiveInnings(data);
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }`,
    `  Future<void> _fetchMatch() async {
    try {
      final data = await ApiService.getMatch(widget.matchId);
      Map<String, dynamic>? sData;
      if (data['competitionType'] == 'series' && data['seriesId'] != null) {
        try {
          final sId = int.tryParse(data['seriesId'].toString());
          if (sId != null) {
             sData = await ApiService.getSeriesById(sId);
          }
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _match = data;
          _seriesData = sData;
          _loading = false;
          _setActiveInnings(data);
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }`
);

content = content.replace(
    `  Widget _buildScorecard(Map<String, dynamic> match, List<dynamic> innings, String? result) {
    if (match['status'] == 'cancelled') {`,
    `  Widget _buildScorecard(Map<String, dynamic> match, List<dynamic> innings, String? result) {
    final bool isSeries = match['competitionType'] == 'series';
    String seriesLeadStr = '';
    
    if (isSeries && _seriesData != null) {
       final sMatches = List<dynamic>.from(_seriesData!['matches'] ?? []);
       int teamAWins = 0;
       int teamBWins = 0;
       for (var m in sMatches) {
           if (m['status'] == 'completed') {
               String? w = m['winner']?.toString();
               if ((w == null || w.isEmpty) && m['innings'] != null && (m['innings'] as List).length >= 2) {
                   final List<dynamic> inns = m['innings'] as List<dynamic>;
                   Map<dynamic, dynamic>? inn1;
                   Map<dynamic, dynamic>? inn2;
                   if (inns.length >= 4) {
                       inn1 = inns[inns.length - 2] as Map<dynamic, dynamic>;
                       inn2 = inns[inns.length - 1] as Map<dynamic, dynamic>;
                   } else {
                       inn1 = inns[0] as Map<dynamic, dynamic>;
                       inn2 = inns[1] as Map<dynamic, dynamic>;
                   }
                   final int r1 = (inn1['runs'] as num?)?.toInt() ?? 0;
                   final int r2 = (inn2['runs'] as num?)?.toInt() ?? 0;
                   if (r1 > r2) w = inn1['team']?.toString();
                   else if (r2 > r1) w = inn2['team']?.toString();
               }

               if (w != null && w.isNotEmpty && w != 'Draw' && w != 'Tie' && w != 'Abandoned') {
                   final teamAStr = (m['teamA']?.toString() ?? '').toLowerCase();
                   final teamBStr = (m['teamB']?.toString() ?? '').toLowerCase();
                   if (w.toLowerCase() == teamAStr) teamAWins++;
                   if (w.toLowerCase() == teamBStr) teamBWins++;
               }
           }
       }
       
       if (teamAWins == teamBWins) {
           seriesLeadStr = 'Tied $teamAWins - $teamBWins';
       } else {
           final leader = teamAWins > teamBWins ? (sMatches.isNotEmpty ? sMatches[0]['teamA'] : 'Team A') : (sMatches.isNotEmpty ? sMatches[0]['teamB'] : 'Team B');
           seriesLeadStr = '$leader leads \${teamAWins > teamBWins ? teamAWins : teamBWins}-\${teamAWins < teamBWins ? teamAWins : teamBWins}';
       }
    }

    if (match['status'] == 'cancelled') {`
);

content = content.replace(
    `              children: [
                Row(
                  children: [
                    Icon(Icons.location_on`,
    `              children: [
                if (isSeries) ...[
                  Text('Match \${match['matchNumber'] ?? ''} of \${_seriesData != null ? (_seriesData!['matches'] as List).length : '?'}', 
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.grey.shade800, letterSpacing: 0.5)),
                  const SizedBox(height: 8),
                  if (_seriesData != null) ...[
                      Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: _primary.withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
                          child: Text('Series Lead : $seriesLeadStr', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: _primary, fontSize: 13)),
                      ),
                      const SizedBox(height: 12),
                  ],
                  if (_seriesData != null && _seriesData!['matches'] != null) ...[
                     SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                           children: (List<dynamic>.from(_seriesData!['matches'] ?? [])..sort((a,b) => (int.tryParse(a['matchNumber']?.toString() ?? '0') ?? 0).compareTo(int.tryParse(b['matchNumber']?.toString() ?? '0') ?? 0)))
                             .map((sm) {
                                final isCurrent = sm['_id'] == match['_id'] || sm['id'] == match['id'] || sm['_id'] == match['id'];
                                final statusSuffix = sm['status'] == 'upcoming' ? '(Upcoming)' : (sm['status'] == 'completed' ? '(Completed)' : '');
                                return Padding(
                                   padding: const EdgeInsets.only(right: 8),
                                   child: InkWell(
                                      onTap: () {
                                          if (!isCurrent) {
                                              final sIdStr = (sm['_id'] ?? sm['id']).toString();
                                              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ScorecardScreen(matchId: sIdStr)));
                                          }
                                      },
                                      child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          decoration: BoxDecoration(
                                              color: isCurrent ? _primary : Colors.white,
                                              border: Border.all(color: isCurrent ? _primary : Colors.grey.shade300),
                                              borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text('Match \${sm['matchNumber'] ?? ''} \${statusSuffix.isNotEmpty ? statusSuffix : ''}',
                                              style: GoogleFonts.outfit(color: isCurrent ? Colors.white : Colors.grey.shade700, fontWeight: FontWeight.w800, fontSize: 12)),
                                      ),
                                   ),
                                );
                             }).toList(),
                        ),
                     ),
                     const SizedBox(height: 16),
                  ],
                ],
                Row(
                  children: [
                    Icon(Icons.location_on`
);

content = content.replace(
    `                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.12),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.amber.withOpacity(0.2)),
                        ),
                        child: const Icon(Icons.emoji_events, size: 22, color: Colors.amber),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('MAN OF THE MATCH', 
                            style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 8, color: Colors.grey, letterSpacing: 1.2)),
                          Text(match['manOfTheMatch'].toString().toUpperCase(), 
                            style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18, color: _primary, letterSpacing: 0.5)),
                        ],
                      ),`,
    `                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4B400).withOpacity(0.12),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFF4B400).withOpacity(0.4)),
                        ),
                        child: const Icon(Icons.star_rounded, size: 26, color: Color(0xFFF4B400)),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('MAN OF THE MATCH', 
                            style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 8, color: Colors.grey, letterSpacing: 1.2)),
                          Text(match['manOfTheMatch'].toString().toUpperCase(), 
                            style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.black87, letterSpacing: 0.5)),
                        ],
                      ),`
);

content = content.replace(
    `            Text('🥇 MAN OF THE MATCH', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 10, color: Colors.amber.shade900, letterSpacing: 1)),
            const SizedBox(height: 6),
            Text(match['manOfTheMatch'].toString().toUpperCase(), style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.amber.shade900)),`,
    `            Row(
              children: [
                const Icon(Icons.star_rounded, size: 18, color: Color(0xFFF4B400)),
                const SizedBox(width: 4),
                Text('MAN OF THE MATCH', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 10, color: Colors.amber.shade900, letterSpacing: 1)),
              ],
            ),
            const SizedBox(height: 6),
            Text(match['manOfTheMatch'].toString().toUpperCase(), style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.amber.shade900)),`
);

fs.writeFileSync(file, content);

