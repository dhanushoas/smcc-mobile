/// home_screen.dart — Full port of smcc-web/src/pages/Home.jsx
/// Real-time match feed with socket.io, boundary & match-complete animations,
/// live score, batsmen, bowler, over balls display, series filter.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../utils/formatters.dart';
import '../utils/calculations.dart';
import 'scorecard_screen.dart';
import 'series_screen.dart';
import 'tournaments/tournament_detail_screen.dart';
import 'points_table_screen.dart';
import 'schedule_screen.dart';
import 'achievements_screen.dart';
import 'join_council_screen.dart';
import 'improvements_screen.dart';
import 'sponsorship_screen.dart';
import 'privacy_screen.dart';
import 'admin/admin_scoring_screen.dart';
import '../widgets/app_drawer.dart';

class HomeScreen extends StatefulWidget {
  final bool isAdminMode;
  const HomeScreen({Key? key, this.isAdminMode = false}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────────
  List<dynamic> _matches = []; // Real-time match data list
  bool _loading = true; // Global loading state

  // Animation tracking — mirrors Web blastMatchId / completeMatchId
  String? _blastMatchId;
  int _blastValue = 0;
  String? _completeMatchId;

  // Entry animation controllers per match card
  final Map<String, AnimationController> _cardControllers = {};

  late io.Socket _socket;
  int _navIndex = 0;
  late PageController _pageController;
  String _activeSeries = 'ALL';
  String _completedFilter = 'ALL'; // Competition type filter for Recently Completed

  // ── Theme ──────────────────────────────────────────────────────────────────
  static const Color _primary  = Color(0xFF2563EB);
  static const Color _danger   = Color(0xFFDC2626);
  static const Color _success  = Color(0xFF059669);
  static const Color _warning  = Color(0xFFD97706);
  static const Color _bgLight  = Color(0xFFF8FAFC);
  static const Color _bgCard   = Colors.white;

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _fetchMatches();
    _connectSocket();
  }

  @override
  void dispose() {
    _socket.dispose();
    for (final c in _cardControllers.values) c.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // ── Data ───────────────────────────────────────────────────────────────────
  Future<void> _fetchMatches() async {
    try {
      final data = await ApiService.getMatches();
      setState(() {
        _matches = data;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _connectSocket() {
    // Initialize Socket.io connection for real-time score broadcasts
    _socket = io.io(ApiService.socketUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
    });

    _socket.on('matchUpdate', (updatedMatch) {
      setState(() {
        final idx = _matches.indexWhere((m) =>
            m['_id'] == updatedMatch['_id'] || m['id'] == updatedMatch['id']);

        // Animation sequencing: Boundary → Match Complete (mirrors Home.jsx)
        if (idx != -1) {
          final oldMatch = _matches[idx];
          final oldBattingTeam = oldMatch['score']?['battingTeam'];
          final oldInnIdx = (oldMatch['innings'] as List? ?? [])
              .indexWhere((inn) => inn['team'] == oldBattingTeam);
          final newInnRuns = oldInnIdx != -1
              ? ((updatedMatch['innings'] as List?)?.elementAtOrNull(oldInnIdx)?['runs'] as num? ?? 0).toInt()
              : 0;
          final oldInnRuns = oldInnIdx != -1
              ? ((oldMatch['innings'] as List?)?.elementAtOrNull(oldInnIdx)?['runs'] as num? ?? 0).toInt()
              : 0;
          final innDiff = newInnRuns - oldInnRuns;

          final matchId = (updatedMatch['_id'] ?? updatedMatch['id']).toString();
          final isJustCompleted = oldMatch['status'] == 'live' && updatedMatch['status'] == 'completed';
          final isBoundary = innDiff == 4 || innDiff == 6;
          final newStatus = updatedMatch['status'] as String?;

          if (isBoundary && (newStatus == 'live' || newStatus == 'completed')) {
            _blastValue = innDiff;
            _blastMatchId = matchId;
            Timer(const Duration(milliseconds: 2500), () {
              if (mounted) {
                setState(() => _blastMatchId = null);
                if (isJustCompleted) {
                  setState(() => _completeMatchId = matchId);
                  Timer(const Duration(milliseconds: 4000), () {
                    if (mounted) setState(() => _completeMatchId = null);
                  });
                }
              }
            });
          } else if (isJustCompleted) {
            setState(() => _completeMatchId = matchId);
            Timer(const Duration(milliseconds: 4000), () {
              if (mounted) setState(() => _completeMatchId = null);
            });
          }

          _matches[idx] = updatedMatch;
        } else {
          _matches.insert(0, updatedMatch);
        }
      });
    });

    _socket.on('matchDeleted', (matchId) {
      setState(() {
        _matches.removeWhere((m) => m['_id'] == matchId || m['id'] == matchId);
      });
    });
  }

  // ── Match Card ─────────────────────────────────────────────────────────────
  Widget _buildMatchCard(dynamic match, [String groupType = 'head-to-head']) {
    final id = (match['_id'] ?? match['id'] ?? '').toString();
    final status = match['computedStatus'] as String? ?? match['status'] as String? ?? '';
    final isLive = status == 'live';
    final isCompleted = status == 'completed';
    final isUpcoming = status == 'upcoming';
    final isLocked = status == 'LOCKED';
    final isCancelled = status == 'CANCELLED';
    final innings = List<dynamic>.from(match['innings'] ?? []);
    final score = match['score'] as Map<String, dynamic>? ?? {};

    final date = DateTime.tryParse(match['date'] ?? '') ?? DateTime.now();
    final matchNum = match['matchNumber'];
    final seriesLabel = (match['series'] ?? 'SMCC LIVE').toString().toUpperCase();
    final matchNumLabel = (groupType == 'series' && matchNum != null) ? ' • MATCH $matchNum' : '';
    final dateLabel = '${const ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][date.month - 1]} ${date.day}';

    // Inn display helper
    String innScore(int idx) {
      if (innings.length <= idx) return '';
      final r = innings[idx]['runs'] ?? 0;
      final w = innings[idx]['wickets'] ?? 0;
      final ov = innings[idx]['overs'] ?? 0;
      return '$r / $w (${pluralize(ov, 'Over')})';
    }

    // Ball dot chip colours (mirrors Home.jsx)
    Color _ballChipColor(String ball) {
      final b = ball.toUpperCase();
      if (b == '6') return _primary;
      if (b == '4') return _success;
      final isWicket = b == 'W' || b == 'OUT';
      final isExtra = b.contains('+') ? (b.startsWith('W+') || b.startsWith('NB+') || b.startsWith('B+') || b.startsWith('LB+')) : (b == 'WD' || b == 'NB' || b == 'LB' || b == 'B');
      if (isWicket) return _danger;
      if (isExtra) return _warning;
      return Colors.grey.shade200;
    }
    Color _ballTextColor(String ball) {
      final b = ball.toUpperCase();
      final isWicket = b == 'W' || b == 'OUT';
      final isExtra = b.contains('+') ? (b.startsWith('W+') || b.startsWith('NB+') || b.startsWith('B+') || b.startsWith('LB+')) : (b == 'WD' || b == 'NB' || b == 'LB' || b == 'B');
      if (b == '6' || b == '4' || isWicket) return Colors.white;
      if (isExtra) return Colors.black;
      return Colors.black87;
    }

    return GestureDetector(
      onTap: () {
        if (isLocked || isCancelled) return;
        if (widget.isAdminMode) {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => AdminScoringScreen(initialMatch: match),
          ));
        } else {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => ScorecardScreen(matchId: id),
          ));
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: _bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            Opacity(
              opacity: isCancelled ? 0.6 : 1.0,
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header bar: series • date + status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          _buildCompetitionBadge(match['competitionType']?.toString(), groupType),
                          const SizedBox(width: 8),
                          Text('$seriesLabel$matchNumLabel • $dateLabel',
                              style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey.shade600, letterSpacing: 1)),
                        ],
                      ),
                      _buildStatusBadge(status),
                    ],
                  ),
                ),

                // ── Body: teams, scores, batsmen, bowler, balls
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Team A row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text((match['teamA'] ?? '').toString().toUpperCase(),
                              style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16))),
                          if (isLive || isCompleted)
                            Text(innScore(0),
                                style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 15, color: _primary)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Team B row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text((match['teamB'] ?? '').toString().toUpperCase(),
                              style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16))),
                          if (isLive || isCompleted)
                            Text(innScore(1),
                                style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.grey.shade700)),
                        ],
                      ),

                      // ── Live: Batsmen + Bowler + Over balls
                      if (isLive) ...[ 
                        if (score['freeHit'] == true) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDC2626).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFDC2626).withOpacity(0.2)),
                            ),
                            alignment: Alignment.center,
                            child: Text('🚀 FREE HIT ACTIVE', 
                              style: GoogleFonts.outfit(color: const Color(0xFFDC2626), fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.2)),
                          ),
                        ],
                        const SizedBox(height: 10),
                        _buildLivePlayerRow(match, score, innings),
                      ],

                      const SizedBox(height: 10),

                      // ── Footer status line
                      Container(
                        padding: const EdgeInsets.only(top: 10),
                        decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade100))),
                        child: _buildStatusLine(match, isLive, isCompleted, isUpcoming, score, innings),
                      ),
                    ],
                  ),
              ),
            ),

            // ── Boundary Overlay (FOUR! / SIX!)
            if (_blastMatchId == id)
              _buildBoundaryOverlay(_blastValue),

            // ── Match Complete Overlay (🏆 MATCH COMPLETE)
            if (_completeMatchId == id)
              _buildCompleteOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildCompetitionBadge(String? type, String groupType) {
    String t = groupType.toUpperCase();
    if (t == 'HEAD-TO-HEAD') t = (type ?? 'HEAD-TO-HEAD').toUpperCase();
    
    Color color = Colors.grey.shade600;
    if (t == 'TOURNAMENT') color = _warning;
    else if (t == 'SERIES') color = _primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        t,
        style: GoogleFonts.outfit(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    if (status == 'live') {
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.5, end: 1.0),
        duration: const Duration(milliseconds: 800),
        builder: (_, v, child) => Opacity(opacity: v, child: child),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: _danger, borderRadius: BorderRadius.circular(20)),
          child: Text('● LIVE', style: GoogleFonts.outfit(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
        ),
      );
    }
    if (status == 'completed') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: _success, borderRadius: BorderRadius.circular(20)),
        child: Text('✓ COMPLETED', style: GoogleFonts.outfit(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
      );
    }
    if (status == 'LOCKED') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(20)),
        child: Text('🔒 LOCKED', style: GoogleFonts.outfit(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
      );
    }
    if (status == 'CANCELLED') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
        child: Text('✕ CANCELLED', style: GoogleFonts.outfit(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: Colors.blue.shade100, borderRadius: BorderRadius.circular(20)),
      child: Text('⏰ UPCOMING', style: GoogleFonts.outfit(color: Colors.blue.shade800, fontSize: 10, fontWeight: FontWeight.w900)),
    );
  }

  Widget _buildLivePlayerRow(dynamic match, Map<String, dynamic> score, List<dynamic> innings) {
    final batsmen = List<dynamic>.from(match['currentBatsmen'] ?? []);
    final bowler = match['currentBowler'] ?? '';
    final thisOver = List<dynamic>.from(score['thisOver'] ?? []);

    if (batsmen.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Batsmen
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('BATTING', style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey.shade600, letterSpacing: 1)),
                const SizedBox(height: 4),
                ...batsmen.map((b) {
                  final onStrike = b['onStrike'] == true;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        if (onStrike) const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.sports_cricket, color: Color(0xFFFF7A00), size: 14)),
                        Expanded(child: Text(toCamelCase(b['name']), overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: onStrike ? const Color(0xFF1E293B) : Colors.grey.shade700))),
                        Text(' ${b['runs'] ?? 0}', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12, color: _primary)),
                        const SizedBox(width: 4),
                        Text('(${b['balls'] ?? 0})', style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600)),
                        if (onStrike) Text('*', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: _danger)),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          Container(width: 1, height: 48, color: Colors.grey.shade200, margin: const EdgeInsets.symmetric(horizontal: 10)),
          // Bowler + over balls
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('BOWLING', style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey.shade600, letterSpacing: 1)),
                const SizedBox(height: 4),
                Row(children: [
                   Container(
                      width: 22, height: 22,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      alignment: Alignment.center,
                      child: const Text('⚾', style: TextStyle(fontSize: 11)),
                   ),
                   Expanded(child: Text(toCamelCase(bowler), overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 12))),
                ]),
                if (thisOver.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: thisOver.map((ball) {
                        final bs = ball.toString().toUpperCase();
                        Color bg = Colors.grey.shade200;
                        Color fg = Colors.black87;
                        if (bs == '6') { bg = _primary; fg = Colors.white; }
                        else if (bs == '4') { bg = _success; fg = Colors.white; }
                        else if (bs.startsWith('W') || bs == 'OUT') { bg = _danger; fg = Colors.white; }
                        else if (bs.startsWith('WD') || bs.startsWith('NB') || bs.startsWith('LB') || bs.startsWith('B')) { bg = _warning; fg = Colors.black; }
                        return Container(
                          margin: const EdgeInsets.only(right: 4),
                          constraints: const BoxConstraints(minWidth: 26),
                          height: 26,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(13)),
                          alignment: Alignment.center,
                          child: Text(ball.toString(), style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w900)),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusLine(dynamic match, bool isLive, bool isCompleted, bool isUpcoming,
      Map<String, dynamic> score, List<dynamic> innings) {
    if (isCompleted) {
      final String winner = calculateWinner(Map<String, dynamic>.from(match)) ?? 'COMPLETED';
      final String resultText = winner.toUpperCase();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7D6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFDE68A), width: 1),
            ),
            child: Row(
              children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(color: const Color(0xFFFFF7D6), shape: BoxShape.circle, border: Border.all(color: const Color(0xFFFDE68A), width: 1.5)),
                  child: const Center(child: Icon(Icons.emoji_events_rounded, color: Color(0xFFF59E0B), size: 18)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(resultText.toUpperCase(),
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12, color: const Color(0xFF92400E), letterSpacing: 0.2)),
                ),
              ],
            ),
          ),
            if (match['manOfTheMatch'] != null && match['manOfTheMatch'].toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Color(0xFFFBBF24), shape: BoxShape.circle),
                    child: const Icon(Icons.military_tech, size: 12, color: Color(0xFF111827)),
                  ),
                  const SizedBox(width: 6),
                  Text('PLAYER OF THE MATCH: ${match['manOfTheMatch'].toString().toUpperCase()}',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 10, color: const Color(0xFFD97706), letterSpacing: 0.5)),
                ],
              ),
            ),
        ],
      );
    }

    if (isLive) {
      final isPaused = score['isPaused'] == true;
      if (isPaused) {
        return Row(children: [
          const Text('⏸ ', style: TextStyle(fontSize: 12)),
          Expanded(child: Text('PAUSED: ${score['pauseReason'] ?? ''}',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.orange.shade800, letterSpacing: 0.5))),
        ]);
      }

      final target = score['target'] as num?;
      if (target != null) {
        final runsNeeded = target - (score['runs'] as num? ?? 0);
        final isSuperOver = innings.length > 2;

        String statusText;
        if (runsNeeded > 0) {
          final rn = runsNeeded.toInt();
          statusText = 'TARGET: $rn ${pluralize(rn, 'Run')} REQUIRED';
        } else {
          statusText = 'SCORES LEVEL';
        }

        return Row(children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: _danger, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 8),
          Expanded(child: Text(isSuperOver ? 'SUPER OVER: $statusText' : statusText,
              style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 11, color: _primary, letterSpacing: 0.2))),
        ]);
      }

      return Row(children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: _danger, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 8),
        Text(innings.length > 2 ? 'SUPER OVER IN PROGRESS' : 'MATCH IN PROGRESS',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 11, color: _primary, letterSpacing: 0.2)),
      ]);
    }

    if (match['computedStatus'] == 'LOCKED') {
      return Row(children: [
        const Icon(Icons.lock, size: 12, color: Colors.grey),
        const SizedBox(width: 4),
        Text('WAITING FOR PREVIOUS MATCH RESULT',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.grey.shade600, letterSpacing: 0.2)),
      ]);
    }
    
    if (match['computedStatus'] == 'CANCELLED') {
      return Row(children: [
        const Icon(Icons.cancel, size: 12, color: Colors.grey),
        const SizedBox(width: 4),
        Text('CANCELLED (SERIES ALREADY WON)',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.grey.shade600, letterSpacing: 0.2)),
      ]);
    }

    // Upcoming
    final venue = match['venue'] ?? 'TBA';
    // Helper to capitalize first letter of each word
    String titleCaseVenue = venue.toString().split(' ').map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}' : '').join(' ');
    
    return Row(children: [
      const Icon(Icons.location_on, size: 12, color: _danger),
      const SizedBox(width: 4),
      Text('${formatTime(match['date'])} • $titleCaseVenue',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.grey.shade800, letterSpacing: 0.2)),
    ]);
  }


  // ── Animations ─────────────────────────────────────────────────────────────
  Widget _buildBoundaryOverlay(int val) {
    final isSix = val == 6;
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
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20)],
              ),
              child: Text(isSix ? 'SIX!' : 'FOUR!',
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900, letterSpacing: 2)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompleteOverlay() {
    return Positioned.fill(
      child: Container(
        color: const Color(0xFF059669).withOpacity(0.92),
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
            builder: (_, v, child) => Opacity(opacity: v,
                child: Transform.translate(offset: Offset(0, 20 * (1 - v)), child: child)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🏆', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 8),
                Text('MATCH COMPLETE',
                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 2)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Series Filter Bar ──────────────────────────────────────────────────────
  Widget _buildSeriesFilter(List<String> seriesList) {
    return SizedBox(
      height: 36,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: seriesList.length,
        itemBuilder: (_, i) {
          final s = seriesList[i];
          final isActive = s == _activeSeries;
          return GestureDetector(
            onTap: () => setState(() => _activeSeries = s),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: isActive ? _primary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isActive ? _primary : Colors.grey.shade300),
                boxShadow: isActive ? [BoxShadow(color: _primary.withOpacity(0.3), blurRadius: 8)] : [],
              ),
              child: Text(s,
                  style: GoogleFonts.outfit(
                      color: isActive ? Colors.white : Colors.grey.shade700,
                      fontWeight: FontWeight.w800, fontSize: 12)),
            ),
          );
        },
      ),
    );
  }

  // ── Match List View ────────────────────────────────────────────────────────
  Widget _buildSeriesGroup(Map<String, dynamic> ps) {
    final teamA = ps['teamA'].toString();
    final teamB = ps['teamB'].toString();
    final aw = ps['teamAWins'] as int;
    final bw = ps['teamBWins'] as int;
    final seriesWinner = ps['seriesWinner']?.toString();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Column(
              children: [
                Text('SERIES: $teamA VS $teamB (${ps['totalMatches']} Matches)',
                  style: GoogleFonts.outfit(color: _primary, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
                if (seriesWinner != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: _success, borderRadius: BorderRadius.circular(8)),
                    child: Text('🏆 $seriesWinner won the series ${aw > bw ? aw : bw}-${aw < bw ? aw : bw}',
                      style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
                  ),
                ] else ...[
                  const SizedBox(height: 4),
                  Text('Series Lead: ${aw == bw ? 'Tied $aw-$bw' : (aw > bw ? teamA : teamB) + ' ${aw > bw ? aw : bw}-${aw < bw ? aw : bw}'}',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 11, color: Colors.black87)),
                ]
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: (ps['matches'] as List).map((m) => _buildMatchCard(m, 'series')).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchList() {
    final filtered = _matches;

    final activeItems = <Map<String, dynamic>>[];
    final completedItems = <Map<String, dynamic>>[];

    final seriesGroups = <int, List<dynamic>>{};
    for (var m in filtered) {
      if (m['competitionType'] == 'series' && m['seriesId'] != null) {
        final sId = int.tryParse(m['seriesId'].toString()) ?? 0;
        seriesGroups.putIfAbsent(sId, () => []).add(m);
      }
    }

    for (final sId in seriesGroups.keys) {
      final sMatches = seriesGroups[sId]!;
      sMatches.sort((a, b) => (int.tryParse(a['matchNumber']?.toString() ?? '0') ?? 0)
          .compareTo(int.tryParse(b['matchNumber']?.toString() ?? '0') ?? 0));
          
      int teamAWins = 0;
      int teamBWins = 0;
      String? seriesWinner;
      bool prevCompleted = true;
      final totalMatches = sMatches.length;
      final winsRequired = (totalMatches / 2).floor() + 1;
      
      final teamA = sMatches.isNotEmpty ? (sMatches[0]['teamA'] ?? 'Team A').toString() : 'Team A';
      final teamB = sMatches.isNotEmpty ? (sMatches[0]['teamB'] ?? 'Team B').toString() : 'Team B';
      final seriesName = sMatches.isNotEmpty ? (sMatches[0]['series'] ?? 'Series').toString() : 'Series';
      
      final processedMatches = [];
      
      for (var m in sMatches) {
        String status = m['status']?.toString() ?? 'upcoming';
        String computedStatus = status;
        
        if (seriesWinner != null) {
          if (computedStatus != 'completed') computedStatus = 'CANCELLED';
        } else if (computedStatus == 'upcoming') {
          if (!prevCompleted) {
            computedStatus = 'LOCKED';
          }
        }
        
        if (computedStatus == 'completed' || computedStatus == 'CANCELLED') {
          if (computedStatus == 'completed') {
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
              if (w.toLowerCase() == teamA.toLowerCase()) teamAWins++;
              if (w.toLowerCase() == teamB.toLowerCase()) teamBWins++;
            }
          }
        }
        
        if (seriesWinner == null) {
          if (teamAWins >= winsRequired) seriesWinner = teamA;
          else if (teamBWins >= winsRequired) seriesWinner = teamB;
        }
        
        if (computedStatus == 'completed' || computedStatus == 'CANCELLED') {
          prevCompleted = true;
        } else {
          prevCompleted = false;
        }
        
        final newM = Map<String, dynamic>.from(m);
        newM['computedStatus'] = computedStatus;
        processedMatches.add(newM);
      }
      
      bool isFinished = seriesWinner != null || processedMatches.every((m) => m['computedStatus'] == 'completed' || m['computedStatus'] == 'CANCELLED');
      
      final seriesObj = {
        'seriesId': sId,
        'seriesName': seriesName,
        'teamA': teamA,
        'teamB': teamB,
        'totalMatches': totalMatches,
        'teamAWins': teamAWins,
        'teamBWins': teamBWins,
        'seriesWinner': seriesWinner,
        'matches': processedMatches,
        'isFinished': isFinished,
      };
      
      if (isFinished) completedItems.add({'type': 'series-group', 'data': seriesObj});
      else activeItems.add({'type': 'series-group', 'data': seriesObj});
    }

    for (var m in filtered) {
       final cmpType = m['competitionType']?.toString() ?? 'head-to-head';
       if (cmpType != 'series' || m['seriesId'] == null) {
          final st = m['status']?.toString() ?? 'upcoming';
          if (st == 'live' || st == 'upcoming') {
             activeItems.add({'type': 'single', 'match': m, 'groupType': cmpType});
          } else if (st == 'completed') {
             completedItems.add({'type': 'single', 'match': m, 'groupType': cmpType});
          }
       }
    }

    activeItems.sort((a, b) {
       bool aLive = false;
       bool bLive = false;
       if (a['type'] == 'series-group') {
         aLive = (a['data']['matches'] as List).any((m) => m['computedStatus'] == 'live');
       } else {
         aLive = a['match']['status'] == 'live';
       }
       if (b['type'] == 'series-group') {
         bLive = (b['data']['matches'] as List).any((m) => m['computedStatus'] == 'live');
       } else {
         bLive = b['match']['status'] == 'live';
       }
       if (aLive && !bLive) return -1;
       if (!aLive && bLive) return 1;
       
       String dateA = a['type'] == 'series-group' ? (a['data']['matches'].first['date'] ?? '') : (a['match']['date'] ?? '');
       String dateB = b['type'] == 'series-group' ? (b['data']['matches'].first['date'] ?? '') : (b['match']['date'] ?? '');
       return (DateTime.tryParse(dateA) ?? DateTime.now()).compareTo(DateTime.tryParse(dateB) ?? DateTime.now());
    });

    completedItems.sort((a, b) {
       String dateA = a['type'] == 'series-group' ? (a['data']['matches'].last['date'] ?? '') : (a['match']['date'] ?? '');
       String dateB = b['type'] == 'series-group' ? (b['data']['matches'].last['date'] ?? '') : (b['match']['date'] ?? '');
       return (DateTime.tryParse(dateB) ?? DateTime.now()).compareTo(DateTime.tryParse(dateA) ?? DateTime.now());
    });

    Widget _renderItem(Map<String, dynamic> item) {
       if (item['type'] == 'series-group') {
           return _buildSeriesGroup(item['data']);
       }
       return _buildMatchCard(item['match'], item['groupType'] as String);
    }

    return RefreshIndicator(
      onRefresh: _fetchMatches,
      child: CustomScrollView(
        slivers: [
          // LIVE section header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: _danger, borderRadius: BorderRadius.circular(6)),
                    child: Text('LIVE', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11))),
                const SizedBox(width: 8),
                Text('Match Feed', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 15)),
              ]),
            ),
          ),
          // Live match cards
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: activeItems.isEmpty
                ? SliverToBoxAdapter(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('NO ACTIVE MATCHES',
                              style: GoogleFonts.outfit(color: _primary, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1)),
                          const SizedBox(height: 8),
                          Text('There are no matches currently in progress. Please check back later for live coverage.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(color: Colors.grey.shade600, fontWeight: FontWeight.w600, fontSize: 13)),
                        ],
                      ),
                  )
                : SliverList(delegate: SliverChildBuilderDelegate(
                    (_, i) => _renderItem(activeItems[i]), childCount: activeItems.length)),
          ),
          // Recently completed header + filter
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Recently Completed',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 15, textStyle: const TextStyle(letterSpacing: 0.5))),
                  const SizedBox(height: 10),
                  // Filter chips row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _completedFilterChip('ALL', Icons.grid_view_rounded, 'All'),
                        const SizedBox(width: 6),
                        _completedFilterChip('head-to-head', Icons.people_alt_outlined, 'Head-to-Head'),
                        const SizedBox(width: 6),
                        _completedFilterChip('series', Icons.content_copy_outlined, 'Series'),
                        const SizedBox(width: 6),
                        _completedFilterChip('tournament', Icons.emoji_events_outlined, 'Tournament'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Completed match cards
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
            sliver: (() {
              final filteredCompleted = _completedFilter == 'ALL'
                  ? completedItems
                  : completedItems.where((item) {
                      if (item['type'] == 'series-group') return _completedFilter == 'series';
                      final ct = (item['match']?['competitionType'] ?? 'head-to-head').toString();
                      return ct == _completedFilter;
                    }).toList();

              if (filteredCompleted.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.info_outlined, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text('No Matches Found',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.grey.shade500)),
                        const SizedBox(height: 4),
                        Text('No completed matches for the selected filter.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade400)),
                      ],
                    ),
                  ),
                );
              }
              return SliverList(delegate: SliverChildBuilderDelegate(
                  (_, i) => _renderItem(filteredCompleted[i]), childCount: filteredCompleted.length));
            })(),
          ),
        ],
      ),
    );
  }

  Widget _completedFilterChip(String value, IconData icon, String label) {
    final isActive = _completedFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _completedFilter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? _primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? _primary : Colors.grey.shade300),
          boxShadow: isActive ? [BoxShadow(color: _primary.withOpacity(0.25), blurRadius: 6)] : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: isActive ? Colors.white : Colors.grey.shade600),
            const SizedBox(width: 5),
            Text(label,
                style: GoogleFonts.outfit(
                    color: isActive ? Colors.white : Colors.grey.shade700,
                    fontWeight: FontWeight.w800,
                    fontSize: 12)),
          ],
        ),
      ),
    );
  }

  // ── Navigation ─────────────────────────────────────────────────────────────
  List<Widget> get _pages => [
    _buildMatchList(),
    PointsTableScreen(),
    ScheduleScreen(),
    ScheduleScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        backgroundColor: widget.isAdminMode ? Colors.blueGrey.shade900 : Colors.white,
        foregroundColor: widget.isAdminMode ? Colors.white : Colors.black,
        elevation: 0,
        title: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.hardEdge,
              child: Image.asset('assets/logo.png', height: 32, width: 32),
            ),
            const SizedBox(width: 12),
            Text(
              widget.isAdminMode ? 'ADMIN CONSOLE' : 'SMCC LIVE',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        actions: [
            TextButton.icon(
              onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen(isAdminMode: false))),
              icon: Icon(Icons.exit_to_app, color: Colors.white),
              label: Text('EXIT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          if (!widget.isAdminMode)
            IconButton(
              icon: const Icon(Icons.language, color: _primary),
              tooltip: 'Open SMCC Web',
              onPressed: () async {
                final Uri url = Uri.parse('https://smcc-web.vercel.app/');
                if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not launch SMCC Web')),
                    );
                  }
                }
              },
            ),
        ],
      ),
      drawer: AppDrawer(),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: _primary))
          : _navIndex < _pages.length ? _pages[_navIndex] : _buildMatchList(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: (i) => setState(() => _navIndex = i),
        backgroundColor: Colors.white,
        indicatorColor: _primary.withOpacity(0.15),
        destinations: [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home, color: _primary), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.leaderboard_outlined), selectedIcon: Icon(Icons.leaderboard, color: _primary), label: 'Standings'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month, color: _primary), label: 'Schedule'),
        ],
      ),
    );
  }
}
