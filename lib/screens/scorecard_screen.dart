/// scorecard_screen.dart — Full port of smcc-web/src/pages/FullScorecard.jsx
/// Innings tabs, batting/bowling/extras/FoW tables, target badge (singular/plural),
/// match result, Man of the Match, and PDF download.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../services/api_service.dart';
import '../utils/formatters.dart';
import '../utils/calculations.dart';
import '../services/pdf_service.dart';

class ScorecardScreen extends StatefulWidget {
  final String matchId;
  const ScorecardScreen({Key? key, required this.matchId}) : super(key: key);

  @override
  State<ScorecardScreen> createState() => _ScorecardScreenState();
}

class _ScorecardScreenState extends State<ScorecardScreen> with SingleTickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────────
  Map<String, dynamic>? _match;
  Map<String, dynamic>? _seriesData;
  bool _loading = true;
  int _activeInnings = 0;
  String _activeTab = 'scorecard'; // 'scorecard' | 'info'

  // Boundary animation (mirrors FullScorecard.jsx)
  int _blastValue = 0;
  bool _showBlast = false;

  late io.Socket _socket;

  // ── Theme ──────────────────────────────────────────────────────────────────
  static const Color _primary  = Color(0xFF2563EB);
  static const Color _danger   = Color(0xFFDC2626);
  static const Color _success  = Color(0xFF059669);

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _fetchMatch();
    _connectSocket();
  }

  @override
  void dispose() {
    _socket.dispose();
    super.dispose();
  }

  // ── Data ───────────────────────────────────────────────────────────────────
  Future<void> _fetchMatch() async {
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
  }

  /// Mirrors FullScorecard.jsx auto-select active innings logic
  void _setActiveInnings(Map<String, dynamic> data) {
    final status = data['status'] as String? ?? '';
    final innings = List<dynamic>.from(data['innings'] ?? []);
    if ((status == 'live' || status == 'completed') && innings.isNotEmpty) {
      final bTeam = data['score']?['battingTeam'] as String?;
      if (bTeam != null) {
        final reversed = List.generate(innings.length, (i) => {'inn': innings[i], 'idx': i}).reversed;
        final active = reversed.firstWhere(
          (x) => (x['inn']['team'] as String?)?.trim().toLowerCase() == bTeam.trim().toLowerCase(),
          orElse: () => {'idx': innings.length - 1},
        );
        _activeInnings = active['idx'] as int;
      } else {
        _activeInnings = innings.length - 1;
      }
    }
  }

  void _connectSocket() {
    _socket = io.io(ApiService.socketUrl, <String, dynamic>{
      'transports': ['websocket'], 'autoConnect': true,
    });
    _socket.on('matchUpdate', (updated) {
      if (updated['_id'] != widget.matchId && updated['id'] != widget.matchId) return;
      setState(() {
        if (_match != null && updated['status'] == 'live') {
          final oldRuns = (_match!['score']?['runs'] as num? ?? 0).toInt();
          final newRuns = (updated['score']?['runs'] as num? ?? 0).toInt();
          final diff = newRuns - oldRuns;
          if (diff == 4 || diff == 6) {
            _blastValue = diff;
            _showBlast = true;
            Timer(const Duration(milliseconds: 2500), () {
              if (mounted) setState(() => _showBlast = false);
            });
          }
        }
        _match = Map<String, dynamic>.from(updated);
      });
    });
  }

  // ── PDF Generation (mirrors AdminDashboard.jsx downloadPDF) ────────────────
  Future<void> _downloadPDF() async {
    if (_match == null) return;
    
    // Compute series lead string for PDF
    String? seriesLeadStr;
    int? seriesTotalMatches;
    if (_match!['competitionType'] == 'series' && _seriesData != null) {
       final sMatches = List<dynamic>.from(_seriesData!['matches'] ?? []);
       seriesTotalMatches = sMatches.length;
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
           seriesLeadStr = '$leader leads ${teamAWins > teamBWins ? teamAWins : teamBWins}-${teamAWins < teamBWins ? teamAWins : teamBWins}';
       }
    }

    await PdfService.generateScorecard(_match!, seriesLeadStr: seriesLeadStr, seriesTotalMatches: seriesTotalMatches);
  }

  String _ordinal(int n) {
    final s = ['th', 'st', 'nd', 'rd'];
    final v = n % 100;
    return '$n${s[(v - 20) % 10 >= 0 && (v - 20) % 10 < s.length ? (v - 20) % 10 : (v < s.length ? v : 0)]}';
  }

  // ── UI ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text('Full Scorecard', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
        actions: [
          if (_match != null && _match!['status'] == 'completed')
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'Export PDF',
              onPressed: _downloadPDF,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _match == null
              ? Center(child: Text('Match not found', style: GoogleFonts.outfit()))
              : Stack(children: [
                  _buildBody(),
                  if (_showBlast) _buildBoundaryOverlay(),
                ]),
    );
  }

  Widget _buildBody() {
    final match = _match!;
    final innings = List<dynamic>.from(match['innings'] ?? []);
    final result = calculateWinner(match);
    final date = DateTime.tryParse(match['date'] ?? '') ?? DateTime.now();

    return Column(
      children: [
        // ── Main tab bar: Scorecard | Match Info
        Container(
          color: Colors.white,
          child: Row(
            children: ['scorecard', 'info'].map((tab) {
              final isActive = _activeTab == tab;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _activeTab = tab),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(
                          color: isActive ? _primary : Colors.transparent, width: 3)),
                    ),
                    alignment: Alignment.center,
                    child: Text(tab == 'scorecard' ? 'Scorecard' : 'Match Info',
                        style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w800, fontSize: 14,
                            color: isActive ? _primary : Colors.grey)),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        Expanded(child: _activeTab == 'scorecard'
            ? _buildScorecard(match, innings, result)
            : _buildMatchInfo(match, result, date)),
      ],
    );
  }

  Widget _buildScorecard(Map<String, dynamic> match, List<dynamic> innings, String? result) {
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
           seriesLeadStr = '$leader leads ${teamAWins > teamBWins ? teamAWins : teamBWins}-${teamAWins < teamBWins ? teamAWins : teamBWins}';
       }
    }

    if (match['status'] == 'cancelled') {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.not_interested, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('MATCH NOT REQUIRED', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.grey.shade800)),
            const SizedBox(height: 8),
            Text('This match was cancelled as the series was\ndecided in earlier matches.', textAlign: TextAlign.center, style: GoogleFonts.outfit(color: Colors.grey.shade600)),
          ],
        ),
      );
    }
    if (innings.isEmpty) {
      return Center(child: Text('No innings data yet.', style: GoogleFonts.outfit(color: Colors.grey)));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isSeries) ...[
                  Text('Match ${match['matchNumber'] ?? ''} of ${_seriesData != null ? (_seriesData!['matches'] as List).length : '?'}', 
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.grey.shade800, letterSpacing: 0.5)),
                  const SizedBox(height: 8),
                  if (_seriesData != null) ...[
                      Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: _primary.withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
                          child: Text('Series Standing : $seriesLeadStr', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: _primary, fontSize: 13)),
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
                                          child: Text('Match ${sm['matchNumber'] ?? ''} ${statusSuffix.isNotEmpty ? statusSuffix : ''}',
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
                    _buildCompetitionBadge(match['competitionType']?.toString(), (match['series'] ?? 'Tournament').toString()),
                    if (match['matchNumber'] != null) ...[
                      const SizedBox(width: 8),
                      Text('• MATCH ${match['matchNumber']}',
                          style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.grey.shade800, letterSpacing: 0.5)),
                    ],
                    if (match['status'] == 'completed') ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(100)),
                        child: Text('COMPLETED', style: GoogleFonts.outfit(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 14, color: _primary),
                    const SizedBox(width: 4),
                    Text('${formatTime(match['date'])} • ${(match['venue'] ?? 'TBA').toString().split(' ').map((s) => s.isNotEmpty ? s[0].toUpperCase() + s.substring(1) : '').join(' ')}', 
                        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                  ],
                ),
                const SizedBox(height: 8),
                if (match['toss']?['winner'] != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 16, color: Colors.indigo),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${match['toss']['winner'].toString().toUpperCase()} WON TOSS & ELECTED TO ${match['toss']['decision'].toString().toUpperCase()} FIRST',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _primary.withOpacity(0.05),
                  Colors.white,
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _primary.withOpacity(0.1)),
              boxShadow: [
                BoxShadow(
                  color: _primary.withOpacity(0.03),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: (match['status'] == 'completed' && result != null) ? Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('MATCH COMPLETED', 
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 10, color: Colors.green, letterSpacing: 1.5)),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.emoji_events, color: Color(0xFFF59E0B), size: 36),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(result.toUpperCase(), 
                        textAlign: TextAlign.left,
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18, color: const Color(0xFF92400E), height: 1.2)),
                    ),
                  ],
                ),
                if (match['manOfTheMatch'] != null && match['manOfTheMatch'].toString().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.star, size: 32, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('MAN OF THE MATCH', 
                            style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 8, color: Colors.grey, letterSpacing: 1.2)),
                          Text(match['manOfTheMatch'].toString().toUpperCase(), 
                            style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.black87, letterSpacing: 0.5)),
                        ],
                      ),
                    ],
                  ),
                ],
              ],
            ) : Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('CHASE REQUIREMENT', style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w900, fontSize: 10, color: _danger, letterSpacing: 2)),
                const SizedBox(height: 10),
                Text('TARGET: ${match['score']?['target'] ?? 0} ${pluralize((match['score']?['target'] ?? 0).toInt(), 'Run')}', 
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 20, color: _danger)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: _danger.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('REQUIRED FROM ${match['totalOvers'] ?? 20} OVERS', 
                    style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: _danger)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),


        // ── Innings phase tabs
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('MATCH PHASES', style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w900, fontSize: 10, color: Colors.grey, letterSpacing: 1.5)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: List.generate(innings.length, (idx) {
                final inn = innings[idx] as Map<String, dynamic>;
                if (idx >= 2 && (inn['runs'] ?? 0) == 0 && (inn['wickets'] ?? 0) == 0 &&
                    (inn['batting'] as List? ?? []).isEmpty) return const SizedBox.shrink();
                final isSO = idx >= 2;
                final isActive = _activeInnings == idx;
                return GestureDetector(
                  onTap: () => setState(() => _activeInnings = idx),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isActive ? _primary : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isActive ? _primary : Colors.grey.shade200),
                      boxShadow: isActive ? [BoxShadow(color: _primary.withOpacity(0.3), blurRadius: 8)] : [],
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text((inn['team'] ?? '').toString().toUpperCase(),
                          style: GoogleFonts.outfit(color: isActive ? Colors.white : _primary,
                              fontWeight: FontWeight.w900, fontSize: 11)),
                      Text('${_ordinal(idx + 1)} Inn${isSO ? ' (SO)' : ''}',
                          style: GoogleFonts.outfit(color: isActive ? Colors.white70 : Colors.grey,
                              fontSize: 10, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text('${inn['runs']} / ${inn['wickets']} (${pluralize(inn['overs'] ?? 0, 'Over')})',
                          style: GoogleFonts.outfit(color: isActive ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w900, fontSize: 12)),
                    ]),
                  ),
                );
              })),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Active innings header + target badge
        _buildInningsHeader(match, innings),
        const SizedBox(height: 16),

        // ── Batting table
        if ((innings[_activeInnings]['batting'] as List? ?? []).isNotEmpty) ...[
          _buildSectionTitle('Batting'),
          _buildBattingTable(match, List<dynamic>.from(innings[_activeInnings]['batting'] ?? [])),
          _buildYetToBat(match, innings[_activeInnings]),
          const SizedBox(height: 4),
          _buildExtrasRow(innings[_activeInnings]),
          _buildHitBreakdown(innings[_activeInnings]),
          const SizedBox(height: 16),
        ],

        // ── Bowling table (from opposing innings)
        ..._buildBowlingSection(match, innings),

        // ── Fall of Wickets
        if ((innings[_activeInnings]['fallOfWickets'] as List? ?? []).isNotEmpty) ...[
          _buildSectionTitle('Fall of Wickets'),
          _buildFoWTable(List<dynamic>.from(innings[_activeInnings]['fallOfWickets'])),
          const SizedBox(height: 16),
        ],

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildInningsHeader(Map<String, dynamic> match, List<dynamic> innings) {
    final inn = innings[_activeInnings] as Map<String, dynamic>;
    final isSecondInn = _activeInnings % 2 != 0 && _activeInnings > 0;
    final isSO = _activeInnings >= 2;
    final ovs = isSO ? 1 : (match['totalOvers'] as num? ?? 20).toInt();
    final target = (match['score']?['target'] as num?) ?? ((innings[_activeInnings - (isSecondInn ? 1 : 0)]['runs'] as num? ?? 0) + 1);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${(inn['team'] ?? '').toString().toUpperCase()} ${_ordinal(_activeInnings + 1)} INNINGS${isSO ? ' (Super Over)' : ''}',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: _primary)),
          Text(isSO ? 'Total 1 over' : 'Total ${match['totalOvers']} overs',
              style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w700)),
        ]),

      ],
    );
  }

  Widget _buildBattingTable(Map<String, dynamic> match, List<dynamic> batting) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      clipBehavior: Clip.hardEdge,
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(2.2),
          1: FlexColumnWidth(2),
          2: FlexColumnWidth(0.7),
          3: FlexColumnWidth(0.7),
          4: FlexColumnWidth(0.7),
          5: FlexColumnWidth(0.7),
          6: FlexColumnWidth(0.9),
        },
        children: [
          _tableHeader(['BATTER', 'STATUS', 'RUNS', 'BALLS', 'FOURS', 'SIXES', 'SR'], dark: true),
          ...List.generate(batting.length, (idx) {
            final b = batting[idx];
            final bool isLive = match['status'] == 'live';
            final bool isCurrentInn = match['score']?['battingTeam'] == match['innings'][_activeInnings]['team'];
            final List currentBatsmen = List.from(match['currentBatsmen'] ?? []);
            final bool onStrike = isLive && isCurrentInn && currentBatsmen.any((cb) => cb['name'] == b['player'] && cb['onStrike'] == true);
            
            return _tableRow([
              toCamelCase(b['player']),
              toCamelCase(b['status'] ?? ''),
              '${b['runs'] ?? 0}',
              '${b['balls'] ?? 0}',
              '${b['fours'] ?? 0}',
              '${b['sixes'] ?? 0}',
              '${b['strikeRate'] ?? 0}',
            ], isFirst: true, onStrike: onStrike);
          }),
        ],
      ),
    );
  }

  Widget _buildExtrasRow(Map<String, dynamic> inn) {
    final ext = inn['extras'] as Map<String, dynamic>? ?? {};
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        'Extras: ${ext['total'] ?? 0} (W ${ext['wides'] ?? 0}, NB ${ext['noBalls'] ?? 0}, B ${ext['byes'] ?? 0}, LB ${ext['legByes'] ?? 0})',
        style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w800, textStyle: const TextStyle(letterSpacing: 0.2)),
      ),
    );
  }

  Widget _buildHitBreakdown(Map<String, dynamic> inn) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        'Dots:${inn['dots'] ?? 0}  1s:${inn['ones'] ?? 0}  2s:${inn['twos'] ?? 0}  3s:${inn['threes'] ?? 0}  4s:${inn['fours'] ?? 0}  6s:${inn['sixes'] ?? 0}',
        style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildYetToBat(Map<String, dynamic> match, Map<String, dynamic> currentInnings) {
    final squad = currentInnings['team'] == match['teamA'] ? match['teamASquad'] : match['teamBSquad'];
    if (squad == null || (squad as List).isEmpty) return const SizedBox.shrink();
    
    final battedPlayers = (currentInnings['batting'] as List? ?? []).map((b) => b['player']).toList();
    final yetToBat = squad.where((p) => p != null && p.toString().trim().isNotEmpty && !battedPlayers.contains(p)).toList();
    
    if (yetToBat.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.grey.shade50, border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('YET TO BAT:  ', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 0.5)),
          Expanded(child: Text(yetToBat.map((p) => toCamelCase(p.toString())).join(', '), style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _buildYetToBowl(Map<String, dynamic> match, Map<String, dynamic> bowlingInnings) {
    if (bowlingInnings['team'] == null) return const SizedBox.shrink();
    
    final bowlingTeamName = bowlingInnings['team'];
    final squad = bowlingTeamName == match['teamA'] ? match['teamASquad'] : match['teamBSquad'];
    if (squad == null || (squad as List).isEmpty) return const SizedBox.shrink();

    final bowledPlayers = (bowlingInnings['bowling'] as List? ?? []).map((b) => b['player']).toList();
    final yetToBowl = squad.where((p) => p != null && p.toString().trim().isNotEmpty && !bowledPlayers.contains(p)).toList();

    if (yetToBowl.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.grey.shade50, border: Border(top: BorderSide(color: Colors.grey.shade200))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('YET TO BOWL:  ', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 0.5)),
          Expanded(child: Text(yetToBowl.map((p) => toCamelCase(p.toString())).join(', '), style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  List<Widget> _buildBowlingSection(Map<String, dynamic> match, List<dynamic> innings) {
    final bowlInnIdx = _activeInnings.isEven ? _activeInnings + 1 : _activeInnings - 1;
    if (bowlInnIdx < 0 || bowlInnIdx >= innings.length) return [];
    final bowlInn = innings[bowlInnIdx] as Map<String, dynamic>;
    final bowling = List<dynamic>.from(bowlInn['bowling'] ?? []);
    if (bowling.isEmpty) return [];

    return [
      _buildSectionTitle('Bowling'),
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade100),
        ),
        clipBehavior: Clip.hardEdge,
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(2),
            1: FlexColumnWidth(0.7),
            2: FlexColumnWidth(0.7),
            3: FlexColumnWidth(0.7),
            4: FlexColumnWidth(0.7),
            5: FlexColumnWidth(0.7),
            6: FlexColumnWidth(0.7),
            7: FlexColumnWidth(0.9),
          },
          children: [
            _tableHeader(['BOWLER', 'OVERS', 'MAIDENS', 'RUNS', 'WICKETS', 'WIDES', 'NO BALLS', 'ECONOMY'], dark: false),
            ...bowling.map((b) => _tableRow([
              toCamelCase(b['player']),
              '${b['overs'] ?? 0}',
              '${b['maidens'] ?? 0}',
              '${b['runs'] ?? 0}',
              '${b['wickets'] ?? 0}',
              '${b['wides'] ?? 0}',
              '${b['noBalls'] ?? 0}',
              '${b['economy'] ?? 0}',
            ])),
          ],
        ),
      ),
      _buildYetToBowl(match, bowlInn),
      const SizedBox(height: 16),
    ];
  }

  Widget _buildFoWTable(List<dynamic> fow) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade100)),
      clipBehavior: Clip.hardEdge,
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(0.7),
          1: FlexColumnWidth(1),
          2: FlexColumnWidth(0.7),
          3: FlexColumnWidth(2),
        },
        children: [
          _tableHeader(['WICKET', 'SCORE', 'OVER', 'PLAYER'], dark: false),
          ...fow.map((f) => _tableRow(['${f['wicket']}', '${f['runs']}', '${f['overs']}', toCamelCase(f['player'])])),
        ],
      ),
    );
  }

  TableRow _tableHeader(List<String> cols, {bool dark = true}) {
    return TableRow(
      decoration: BoxDecoration(color: dark ? const Color(0xFF1E293B) : Colors.grey.shade700),
      children: cols.map((c) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        child: Text(c, style: GoogleFonts.outfit(
            color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10)),
      )).toList(),
    );
  }

  TableRow _tableRow(List<String> cells, {bool isFirst = false, bool onStrike = false}) {
    return TableRow(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
      children: cells.indexed.map((e) {
        final isName = isFirst && e.$1 == 0;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isName && onStrike) const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.sports_cricket, color: Color(0xFFFF7A00), size: 14)),
              Expanded(
                child: Text(e.$2 + (isName && onStrike ? '*' : ''),
                    style: GoogleFonts.outfit(
                        fontWeight: (isName || onStrike) ? FontWeight.w900 : FontWeight.w500,
                        fontSize: 11,
                        color: onStrike ? const Color(0xFF2563EB) : Colors.black87),
                    overflow: isName ? TextOverflow.ellipsis : TextOverflow.clip),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title.toUpperCase(),
          style: GoogleFonts.outfit(
              fontWeight: FontWeight.w900, fontSize: 11,
              color: Colors.grey, letterSpacing: 1.5)),
    );
  }

  Widget _buildMatchInfo(Map<String, dynamic> match, String? result, DateTime date) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      // Match header
      _infoCard('MATCH DETAILS', [
        _infoRow('Teams', '${match['teamA']} vs ${match['teamB']}'),
        _infoRow('Series', match['series'] ?? 'SMCC LIVE'),
        _infoRow('Ground', match['venue'] ?? 'TBA'),
        _infoRow('Toss', match['toss']?['winner'] != null ? '${match['toss']['winner']}, elected to ${match['toss']['decision']} first' : 'To be decided'),
        _infoRow('Date & Time', '${date.day}/${date.month}/${date.year} at ${formatTime(match['date'])}'),
        _infoRow('Match Format', '${pluralize(match['totalOvers'] ?? 20, 'Over')}'),
      ]),
      if (result != null) ...[
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7D6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFDE68A), width: 1),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: const Color(0xFFFFF7D6), shape: BoxShape.circle, border: Border.all(color: const Color(0xFFFDE68A))),
                child: const Icon(Icons.emoji_events, color: Color(0xFFF59E0B), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('MATCH RESULT', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 10, color: const Color(0xFF92400E), letterSpacing: 1)),
                    const SizedBox(height: 2),
                    Text(result.toUpperCase(), style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: const Color(0xFF92400E))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
      if (match['manOfTheMatch'] != null && match['manOfTheMatch'].toString().isNotEmpty) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.amber.withOpacity(0.2)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(
              children: [
                const Text('🥇', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Text('MAN OF THE MATCH', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 10, color: Colors.amber.shade900, letterSpacing: 1)),
              ],
            ),
            const SizedBox(height: 6),
            Text(match['manOfTheMatch'].toString().toUpperCase(), style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.amber.shade900)),
          ]),
        ),
      ],
    ]);
  }

  Widget _infoCard(String title, List<Widget> rows) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 10, color: Colors.grey, letterSpacing: 1.5)),
        const SizedBox(height: 10),
        ...rows,
      ]),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
        Text(value, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w800)),
      ]),
    );
  }

  Widget _buildCompetitionBadge(String? type, [String seriesName = 'SMCC']) {
    final t = (type ?? 'head-to-head').toLowerCase();
    Color color = Colors.grey.shade600;
    String label = 'HEAD-TO-HEAD';
    if (t == 'tournament') {
        color = Colors.orange;
        label = seriesName.toUpperCase();
    } else if (t == 'series') {
        color = const Color(0xFF2563EB);
        label = seriesName.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildBoundaryOverlay() {
    final isSix = _blastValue == 6;
    return Positioned.fill(
      child: Container(
        color: Colors.white.withOpacity(0.75),
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 400),
            curve: Curves.elasticOut,
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: isSix
                    ? [const Color(0xFF059669), const Color(0xFF10B981)]
                    : [const Color(0xFFD97706), const Color(0xFFFBBF24)]),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: [const BoxShadow(color: Colors.black26, blurRadius: 20)],
              ),
              child: Text(isSix ? 'SIX!' : 'FOUR!',
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900)),
            ),
          ),
        ),
      ),
    );
  }
}
