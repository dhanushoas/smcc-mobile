import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../utils/formatters.dart';
import '../utils/calculations.dart';
import 'scorecard_screen.dart';

class SeriesScreen extends StatefulWidget {
  final int seriesId;
  const SeriesScreen({super.key, required this.seriesId});

  @override
  State<SeriesScreen> createState() => _SeriesScreenState();
}

class _SeriesScreenState extends State<SeriesScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _series;
  List<dynamic> _matches = [];

  static const Color _primary = Color(0xFF032333);
  static const Color _bgCard = Colors.white;
  static const Color _bgLight = Color(0xFFF8FAFC);
  static const Color _danger = Color(0xFFDC2626);
  static const Color _success = Color(0xFF059669);

  @override
  void initState() {
    super.initState();
    _fetchSeries();
  }

  Future<void> _fetchSeries() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.getSeriesById(widget.seriesId);
      setState(() {
        _series = res;
        _matches = List<dynamic>.from(res['matches'] ?? []);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load series details: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildMatchCard(dynamic match) {
    final status = match['status'] as String? ?? '';
    final isLive = status == 'live';
    final isCompleted = status == 'completed';
    final isUpcoming = status == 'upcoming';
    final isCancelled = status == 'cancelled';
    final innings = List<dynamic>.from(match['innings'] ?? []);
    final id = (match['_id'] ?? match['id'] ?? '').toString();

    // Venue title case
    final venue = match['venue'] ?? 'TBA';
    final titleCaseVenue = venue.toString().split(' ').map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}' : '').join(' ');

    String innScore(int idx) {
      if (innings.length <= idx) return '';
      final r = innings[idx]['runs'] ?? 0;
      final w = innings[idx]['wickets'] ?? 0;
      final ov = innings[idx]['overs'] ?? 0;
      return '$r / $w (${pluralize(ov, 'Over')})';
    }

    return GestureDetector(
      onTap: isCancelled ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => ScorecardScreen(matchId: id))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isCancelled ? Colors.grey.shade100 : _bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [if (!isCancelled) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        clipBehavior: Clip.hardEdge,
        child: Opacity(
          opacity: isCancelled ? 0.7 : 1.0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isCancelled ? Colors.grey.shade200 : Colors.grey.shade50,
                  border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        match['matchNumber'] != null
                            ? 'MATCH ${match['matchNumber']}'
                            : (match['title'] ?? match['series'] ?? 'SERIES MATCH').toString().toUpperCase(),
                          style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey.shade600, letterSpacing: 1),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    if (isLive)
                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: _danger, borderRadius: BorderRadius.circular(20)), child: Text('● LIVE', style: GoogleFonts.outfit(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)))
                    else if (isCompleted)
                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: _success, borderRadius: BorderRadius.circular(20)), child: Text('✓ COMPLETED', style: GoogleFonts.outfit(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)))
                    else if (isCancelled)
                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: Colors.grey.shade600, borderRadius: BorderRadius.circular(20)), child: Text('∅ NOT REQUIRED', style: GoogleFonts.outfit(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)))
                    else if (isUpcoming)
                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: Colors.blue.shade100, borderRadius: BorderRadius.circular(20)), child: Text('⏰ UPCOMING', style: GoogleFonts.outfit(color: Colors.blue.shade800, fontSize: 10, fontWeight: FontWeight.w900))),
                  ],
                ),
              ),
              // Body
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Expanded(child: Text((match['teamA'] ?? '').toString().toUpperCase(), style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16))),
                      if (isLive || isCompleted) Text(innScore(0), style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 15, color: _primary)),
                    ]),
                    const SizedBox(height: 6),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Expanded(child: Text((match['teamB'] ?? '').toString().toUpperCase(), style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16))),
                      if (isLive || isCompleted) Text(innScore(1), style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.grey.shade700)),
                    ]),
                    const SizedBox(height: 10),
                    // Footer lines
                    Container(
                      padding: const EdgeInsets.only(top: 10),
                      decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade100))),
                      child: isCompleted
                          ? Text('🏆 ${(calculateWinner(Map<String, dynamic>.from(match)) ?? 'COMPLETED').toUpperCase()}', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 11, color: _primary, letterSpacing: 0.2))
                          : isCancelled
                              ? Text('SERIES DECIDED EARLY', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.grey.shade600, letterSpacing: 0.2))
                              : isLive
                                  ? Row(children: [Container(width: 6, height: 6, decoration: BoxDecoration(color: _danger, borderRadius: BorderRadius.circular(3))), const SizedBox(width: 8), Text('MATCH IN PROGRESS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 11, color: _primary, letterSpacing: 0.2))])
                                  : Row(children: [const Icon(Icons.location_on, size: 12, color: _danger), const SizedBox(width: 4), Text('${formatTime(match['date'])} • $titleCaseVenue', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.grey.shade800, letterSpacing: 0.2))]),
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: _bgLight,
        appBar: AppBar(title: Text('Series Details', style: GoogleFonts.outfit(fontWeight: FontWeight.bold))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_series == null) {
      return Scaffold(
        backgroundColor: _bgLight,
        appBar: AppBar(title: Text('Error', style: GoogleFonts.outfit(fontWeight: FontWeight.bold))),
        body: const Center(child: Text('Series not found')),
      );
    }

    final seriesName = _series!['name']?.toString().toUpperCase() ?? 'SERIES';
    final seriesType = (_series!['type']?.toString().replaceAll('_', ' ') ?? '').toUpperCase();
    final oversFormat = _series!['oversPerMatch']?.toString() ?? '20';
    final teamA = _series!['teamA'] ?? 'Team A';
    final teamB = _series!['teamB'] ?? 'Team B';
    final seriesStatus = _series!['status'] ?? 'upcoming';
    final seriesWinner = _series!['winner'];

    int teamAWins = 0;
    int teamBWins = 0;
    for (var m in _matches) {
      if (m['status'] == 'completed' && m['score'] != null && m['score']['winner'] != null) {
        if (m['score']['winner'] == teamA) teamAWins++;
        else if (m['score']['winner'] == teamB) teamBWins++;
      }
    }

    // Sort by matchNumber (backend already sends ordered, this is a client fallback)
    final sortedMatches = List<dynamic>.from(_matches)..sort((a, b) {
      final nA = int.tryParse(a['matchNumber']?.toString() ?? '') ?? 0;
      final nB = int.tryParse(b['matchNumber']?.toString() ?? '') ?? 0;
      return nA.compareTo(nB);
    });

    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        title: Text('Series Details', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: CustomScrollView(
        slivers: [
          // Header Card
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _primary,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: _primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBBF24),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('$seriesType SERIES', style: GoogleFonts.outfit(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  ),
                  const SizedBox(height: 12),
                  Text(seriesName, style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1), textAlign: TextAlign.center),
                  const SizedBox(height: 4),
                  Text('$oversFormat OVERS FORMAT', style: GoogleFonts.outfit(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text('$teamAWins', style: GoogleFonts.outfit(color: const Color(0xFFFBBF24), fontSize: 40, fontWeight: FontWeight.w900)),
                            Text(teamA, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1)),
                          ],
                        ),
                      ),
                      Text('VS', style: GoogleFonts.outfit(color: Colors.white.withOpacity(0.34), fontSize: 20, fontWeight: FontWeight.w900)),
                      Expanded(
                        child: Column(
                          children: [
                            Text('$teamBWins', style: GoogleFonts.outfit(color: const Color(0xFFFBBF24), fontSize: 40, fontWeight: FontWeight.w900)),
                            Text(teamB, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: seriesStatus == 'completed' ? _success : Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: seriesStatus == 'completed' ? _success : Colors.white.withOpacity(0.2)),
                    ),
                    child: Text(
                      seriesStatus == 'completed' 
                        ? '🎉 ${seriesWinner?.toString().toUpperCase() ?? "UNKNOWN"} WINS SERIES $teamAWins-$teamBWins'
                        : teamAWins > teamBWins ? '$teamA LEADS $teamAWins-$teamBWins' :
                          teamBWins > teamAWins ? '$teamB LEADS $teamBWins-$teamAWins' :
                          (sortedMatches.isNotEmpty ? 'SERIES LEVEL' : 'SERIES HAS NOT STARTED YET'),
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1),
                    )
                  )
                ],
              ),
            ),
          ),

          
          // Match List Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month, color: _primary, size: 20),
                  const SizedBox(width: 8),
                  Text('SERIES MATCHES', style: GoogleFonts.outfit(color: _primary, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                ],
              ),
            ),
          ),
          
          // Match List
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: sortedMatches.isEmpty
                ? SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                      child: Column(
                        children: [
                          const Icon(Icons.inbox, size: 48, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text('No matches scheduled yet', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
                          const SizedBox(height: 8),
                          Text('Matches for this series will appear here once created.', textAlign: TextAlign.center, style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _buildMatchCard(sortedMatches[i]),
                      childCount: sortedMatches.length,
                    ),
                  ),
          ),
          
        ],
      ),
    );
  }
}
