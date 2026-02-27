/// home_screen.dart — Full port of smcc-web/src/pages/Home.jsx
/// Real-time match feed with socket.io, boundary & match-complete animations,
/// live score, batsmen, bowler, over balls display, series filter.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../services/api_service.dart';
import '../utils/formatters.dart';
import '../utils/calculations.dart';
import 'scorecard_screen.dart';
import 'points_table_screen.dart';
import 'schedule_screen.dart';
import 'achievements_screen.dart';
import 'join_council_screen.dart';
import 'improvements_screen.dart';
import 'sponsorship_screen.dart';
import 'privacy_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────────
  List<dynamic> _matches = [];
  bool _loading = true;
  String _activeSeries = 'ALL';

  // Animation tracking — mirrors Web blastMatchId / completeMatchId
  String? _blastMatchId;
  int _blastValue = 0;
  String? _completeMatchId;

  // Entry animation controllers per match card
  final Map<String, AnimationController> _cardControllers = {};

  late io.Socket _socket;
  int _navIndex = 0;
  late PageController _pageController;

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
  Widget _buildMatchCard(dynamic match) {
    final id = (match['_id'] ?? match['id'] ?? '').toString();
    final status = match['status'] as String? ?? '';
    final isLive = status == 'live';
    final isCompleted = status == 'completed';
    final isUpcoming = status == 'upcoming';
    final innings = List<dynamic>.from(match['innings'] ?? []);
    final score = match['score'] as Map<String, dynamic>? ?? {};

    final date = DateTime.tryParse(match['date'] ?? '') ?? DateTime.now();
    final seriesLabel = (match['series'] ?? 'SMCC LIVE').toString().toUpperCase();
    final dateLabel = '${const ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][date.month - 1]} ${date.day}';

    // Inn display helper
    String innScore(int idx) {
      if (innings.length <= idx) return '';
      final r = innings[idx]['runs'] ?? 0;
      final w = innings[idx]['wickets'] ?? 0;
      final ov = innings[idx]['overs'] ?? 0;
      return '$r/$w (${ov}ov)';
    }

    // Ball dot chip colours (mirrors Home.jsx)
    Color _ballChipColor(String ball) {
      final b = ball.toUpperCase();
      if (b == '6') return _primary;
      if (b == '4') return _success;
      if (b == 'W' || b == 'OUT') return _danger;
      if (b.contains('WD') || b.contains('NB')) return _warning;
      return Colors.grey.shade200;
    }
    Color _ballTextColor(String ball) {
      final b = ball.toUpperCase();
      if (b == '6' || b == '4' || b == 'W' || b == 'OUT') return Colors.white;
      if (b.contains('WD') || b.contains('NB')) return Colors.black;
      return Colors.black87;
    }

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => ScorecardScreen(matchId: id),
      )),
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
            Column(
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
                      Text('$seriesLabel • $dateLabel',
                          style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey.shade600, letterSpacing: 1)),
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
              ],
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
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      children: [
                        Text(onStrike ? '🏏 ' : '   ', style: const TextStyle(fontSize: 11)),
                        Expanded(child: Text(toCamelCase(b['name']), overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 12))),
                        Text(' ${b['runs'] ?? 0}', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12, color: _primary)),
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
                  const Text('⚾ ', style: TextStyle(fontSize: 11)),
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
                        else if (bs == 'W' || bs == 'OUT') { bg = _danger; fg = Colors.white; }
                        else if (bs.contains('WD') || bs.contains('NB')) { bg = _warning; fg = Colors.black; }
                        return Container(
                          margin: const EdgeInsets.only(right: 4),
                          width: 22, height: 22,
                          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(11)),
                          alignment: Alignment.center,
                          child: Text(ball.toString(), style: TextStyle(color: fg, fontSize: 9, fontWeight: FontWeight.w900)),
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
      final result = calculateWinner(Map<String, dynamic>.from(match)) ?? 'COMPLETED';
      final isDLS = match['isDLS'] == true;
      final resultText = isDLS ? '$result (DLS)' : result;
      final mom = match['manOfTheMatch'] as String?;

      return Row(
        children: [
          Expanded(
            child: Text(resultText,
                style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12, color: _primary)),
          ),
          if (mom != null && mom.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _primary.withOpacity(0.2)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Text('🥇 ', style: TextStyle(fontSize: 10)),
                Text(mom.toUpperCase(),
                    style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: _primary)),
              ]),
            ),
        ],
      );
    }

    if (isLive) {
      final isPaused = score['isPaused'] == true;
      if (isPaused) {
        return Row(children: [
          const Text('⏸ ', style: TextStyle(fontSize: 13)),
          Expanded(child: Text('MATCH PAUSED: ${score['pauseReason'] ?? ''}',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 12, color: Colors.orange.shade700))),
        ]);
      }

      final target = score['target'] as num?;
      final isSuperOver = innings.length > 2;
      final totalOvers = isSuperOver ? 1 : ((match['totalOvers'] as num?)?.toInt() ?? 20);

      if (target != null) {
        final runs = (score['runs'] as num? ?? 0).toDouble();
        final overs = (score['overs'] as num? ?? 0).toDouble();
        final ballsBowled = (overs.floor() * 6) + (overs * 10 % 10).round();
        final totalBalls = totalOvers * 6;
        final remainingBalls = (totalBalls - ballsBowled).clamp(0, totalBalls);
        final runsNeeded = target - runs;
        final battingTeam = score['battingTeam'] ?? '';
        final isDLS = match['isDLS'] == true;

        String statusText;
        if (runsNeeded > 0) {
          final rn = runsNeeded.toInt();
          statusText = '$battingTeam needs $rn ${rn == 1 ? 'run' : 'runs'} from $remainingBalls ${remainingBalls == 1 ? 'ball' : 'balls'} to win${isDLS ? ' (DLS)' : ''}';
        } else {
          statusText = 'Scores Level${isDLS ? ' (DLS)' : ''}';
        }

        return Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: _danger, borderRadius: BorderRadius.circular(4))),
          const SizedBox(width: 6),
          Expanded(child: Text(isSuperOver ? 'Match Tied | (Super Over) - $statusText' : statusText,
              style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 11, color: _primary),
              overflow: TextOverflow.ellipsis, maxLines: 2)),
        ]);
      }

      return Row(children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: _danger, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 6),
        Text(isSuperOver ? 'Match Tied | Super Over in progress' : 'Match in progress',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 12, color: _primary)),
      ]);
    }

    // Upcoming
    final venue = match['venue'] ?? 'TBA';
    return Row(children: [
      const Text('📍 ', style: TextStyle(fontSize: 12)),
      Text('Starting ${formatTime(match['date'])} • $venue',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 12, color: Colors.black87)),
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
  Widget _buildMatchList() {
    final seriesList = ['ALL', ..._matches.map((m) => (m['series'] ?? 'SMCC LIVE').toString()).toSet()];
    final filtered = _activeSeries == 'ALL'
        ? _matches
        : _matches.where((m) => (m['series'] ?? 'SMCC LIVE').toString() == _activeSeries).toList();

    final live = filtered.where((m) => m['status'] == 'live' || m['status'] == 'upcoming').toList();
    final completed = filtered.where((m) => m['status'] == 'completed').toList();

    return RefreshIndicator(
      onRefresh: _fetchMatches,
      child: CustomScrollView(
        slivers: [
          // Series filter tabs
          if (seriesList.length > 1)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 14, bottom: 4),
                child: _buildSeriesFilter(seriesList),
              ),
            ),
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
            sliver: live.isEmpty
                ? SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200)),
                      child: Center(child: Text('No live matches in this series',
                          style: GoogleFonts.outfit(color: Colors.grey, fontWeight: FontWeight.w600))),
                    ),
                  )
                : SliverList(delegate: SliverChildBuilderDelegate(
                    (_, i) => _buildMatchCard(live[i]), childCount: live.length)),
          ),
          // Recently completed header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Text('Recently Completed',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 15, textStyle: const TextStyle(letterSpacing: 0.5))),
            ),
          ),
          // Completed match cards
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
            sliver: completed.isEmpty
                ? SliverToBoxAdapter(
                    child: Text('No recently completed matches.',
                        style: GoogleFonts.outfit(color: Colors.grey, fontSize: 13)))
                : SliverList(delegate: SliverChildBuilderDelegate(
                    (_, i) => _buildMatchCard(completed[i]), childCount: completed.length)),
          ),
        ],
      ),
    );
  }

  // ── Navigation ─────────────────────────────────────────────────────────────
  List<Widget> get _pages => [
    _buildMatchList(),
    PointsTableScreen(),
    ScheduleScreen(),
    AchievementsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: _danger, borderRadius: BorderRadius.circular(4))),
          const SizedBox(width: 8),
          Text('SMCC LIVE', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1)),
        ]),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (val) {
              Widget screen;
              switch (val) {
                case 'join': screen = JoinCouncilScreen(); break;
                case 'improve': screen = ImprovementsScreen(); break;
                case 'sponsor': screen = SponsorshipScreen(); break;
                case 'privacy': screen = PrivacyScreen(); break;
                default: return;
              }
              Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'join', child: Text('Join Council')),
              PopupMenuItem(value: 'improve', child: Text('Suggest Improvements')),
              PopupMenuItem(value: 'sponsor', child: Text('Sponsorship')),
              PopupMenuItem(value: 'privacy', child: Text('Privacy Policy')),
            ],
          )
        ],
      ),
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
          NavigationDestination(icon: Icon(Icons.emoji_events_outlined), selectedIcon: Icon(Icons.emoji_events, color: _primary), label: 'Achievements'),
        ],
      ),
    );
  }
}
