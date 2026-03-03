import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../services/api_service.dart';
import '../../core/scoring/scoring_engine.dart';
import '../../core/scoring/match_state.dart';
import '../../core/scoring/scoring_enums.dart';
import '../../services/pdf_service.dart';
import '../../services/auth_service.dart';
import '../../utils/calculations.dart';
import '../../utils/formatters.dart';

class AdminScoringScreen extends StatefulWidget {
  final Map<String, dynamic> initialMatch;

  const AdminScoringScreen({Key? key, required this.initialMatch}) : super(key: key);

  @override
  _AdminScoringScreenState createState() => _AdminScoringScreenState();
}

class _AdminScoringScreenState extends State<AdminScoringScreen> {
  late Map<String, dynamic> match;
  bool isUpdating = false;
  late io.Socket _socket;

  @override
  void initState() {
    super.initState();
    match = widget.initialMatch;
    _connectSocket();
  }

  void _connectSocket() {
    _socket = io.io(ApiService.socketUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
    });
    _socket.on('matchUpdate', (data) {
      final updated = Map<String, dynamic>.from(data);
      if (updated['id'] == (match['id'] ?? match['_id'])) {
        if (mounted) setState(() => match = updated);
      }
    });
    // Add force logout listener for parity
    _socket.on('adminForceLogout', (data) {
        if (mounted) {
            AuthService.logout();
            Navigator.of(context).popUntil((route) => route.isFirst);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚡ Session taken over on another platform.')));
        }
    });
    _socket.on('adminSessionExpired', (data) {
        if (mounted) {
            AuthService.logout();
            Navigator.of(context).popUntil((route) => route.isFirst);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⏱ Session expired. Please log in again.')));
        }
    });
    _socket.on('adminSessionEnded', (data) {
        if (mounted) {
            AuthService.logout();
            Navigator.of(context).popUntil((route) => route.isFirst);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Session ended.')));
        }
    });
  }

  @override
  void dispose() {
    _socket.dispose();
    super.dispose();
  }

  /// Unified Update Handler mirroring AdminDashboard.jsx:handleUpdate
  Future<void> _handleUpdate(String type, {dynamic value, Map<String, dynamic>? params}) async {
    // --- Prevent Editing if Match Completed (Validation Parity) ---
    if (match['status'] == 'completed' && type != 'manual') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Match is completed! No further edits allowed.')));
      return;
    }

    setState(() => isUpdating = true);

    try {
      Map<String, dynamic> payload = {};
      
      if (type == 'manual') {
        payload = Map<String, dynamic>.from(value);
      } else {
        // Build scoring payload mirroring AdminDashboard.jsx
        final currentMatch = Map<String, dynamic>.from(match);
        currentMatch.remove('toss');
        final currentScore = Map<String, dynamic>.from(match['score'] ?? {});
        final innings = List<Map<String, dynamic>>.from((match['innings'] as List).map((e) => Map<String, dynamic>.from(e)));
        
        final target = currentScore['target'];
        final battingTeamIdx = target != null ? 1 : 0;
        final bowlingTeamIdx = battingTeamIdx == 0 ? 1 : 0;
        
        final currentInn = innings[battingTeamIdx];
        final currentBowlInn = innings[bowlingTeamIdx];
        
        final strikerName = currentScore['striker'];
        final nonStrikerName = currentScore['nonStriker'];
        final bowlerName = currentScore['bowler'];
        
        final batting = List<Map<String, dynamic>>.from(currentInn['batting'] ?? []);
        final bowling = List<Map<String, dynamic>>.from(currentBowlInn['bowling'] ?? []);
        
        int sIdx = batting.indexWhere((p) => p['player'] == strikerName);
        int nsIdx = batting.indexWhere((p) => p['player'] == nonStrikerName);
        int bIdx = bowling.indexWhere((p) => p['player'] == bowlerName);
        
        // Safety: Ensure players exist in stats
        if (sIdx == -1 && strikerName != null) {
          batting.add({'player': strikerName, 'status': 'not out', 'runs': 0, 'balls': 0, 'fours': 0, 'sixes': 0});
          sIdx = batting.length - 1;
        }
        if (nsIdx == -1 && nonStrikerName != null) {
          batting.add({'player': nonStrikerName, 'status': 'not out', 'runs': 0, 'balls': 0, 'fours': 0, 'sixes': 0});
          nsIdx = batting.length - 1;
        }
        if (bIdx == -1 && bowlerName != null) {
          bowling.add({'player': bowlerName, 'overs': 0, 'maidens': 0, 'runs': 0, 'wickets': 0});
          bIdx = bowling.length - 1;
        }

        switch (type) {
          case 'runs':
            final runs = value as int;
            currentScore['runs'] = (currentScore['runs'] ?? 0) + runs;
            if (sIdx != -1) {
              batting[sIdx]['runs'] = (batting[sIdx]['runs'] ?? 0) + runs;
              batting[sIdx]['balls'] = (batting[sIdx]['balls'] ?? 0) + 1;
              if (runs == 4) batting[sIdx]['fours'] = (batting[sIdx]['fours'] ?? 0) + 1;
              if (runs == 6) batting[sIdx]['sixes'] = (batting[sIdx]['sixes'] ?? 0) + 1;
            }
            if (bIdx != -1) bowling[bIdx]['runs'] = (bowling[bIdx]['runs'] ?? 0) + runs;
            _advanceBall(currentScore, bIdx != -1 ? bowling[bIdx] : null, false);
            _logBall(currentScore, runs.toString());
            break;
            
          case 'extra':
            final extraType = value as String;
            final amount = params?['amount'] ?? 1;
            final isBOrLB = ['b', 'lb'].contains(extraType);
            final isWOrNB = ['w', 'nb'].contains(extraType);
            
            currentScore['runs'] = (currentScore['runs'] ?? 0) + amount + (isWOrNB ? 1 : 0);
            
            if (isBOrLB) {
               if (sIdx != -1) batting[sIdx]['balls'] = (batting[sIdx]['balls'] ?? 0) + 1;
            }
            if (isWOrNB) {
               if (bIdx != -1) {
                 bowling[bIdx]['runs'] = (bowling[bIdx]['runs'] ?? 0) + amount + 1;
                 if (extraType == 'w') bowling[bIdx]['wides'] = (bowling[bIdx]['wides'] ?? 0) + 1;
                 if (extraType == 'nb') bowling[bIdx]['noBalls'] = (bowling[bIdx]['noBalls'] ?? 0) + 1;
               }
            } else {
               // Byes/Leg Byes don't add to bowler's runs
               if (bIdx != -1) bowling[bIdx]['runs'] = (bowling[bIdx]['runs'] ?? 0) + 0;
            }
            
            _advanceBall(currentScore, bIdx != -1 ? bowling[bIdx] : null, isWOrNB);
            _logBall(currentScore, '${extraType.toUpperCase()}$amount');
            break;
            
          case 'wicket':
            currentScore['wickets'] = (currentScore['wickets'] ?? 0) + 1;
            if (sIdx != -1) {
              batting[sIdx]['balls'] = (batting[sIdx]['balls'] ?? 0) + 1;
              batting[sIdx]['status'] = 'out';
            }
            if (bIdx != -1) bowling[bIdx]['wickets'] = (bowling[bIdx]['wickets'] ?? 0) + 1;
            _advanceBall(currentScore, bIdx != -1 ? bowling[bIdx] : null, false);
            _logBall(currentScore, 'W');
            break;
            
          case 'overthrow':
            final data = value as Map<String, dynamic>;
            final ballType = data['ballType'] as String;
            final runsCompleted = data['runsCompleted'] as int;
            final crossedOnThrow = data['crossedOnThrow'] as bool;
            final resultType = data['resultType'] as String;
            final manualRuns = data['manualRuns'] as int;
            
            final overtimeRuns = resultType == 'boundary' ? 4 : manualRuns;
            final totalRuns = (runsCompleted + (crossedOnThrow ? 1 : 0)) + overtimeRuns;
            
            currentScore['runs'] = (currentScore['runs'] ?? 0) + totalRuns;
            
            if (ballType == 'normal' || ballType == 'nb') {
               if (sIdx != -1) {
                 batting[sIdx]['runs'] = (batting[sIdx]['runs'] ?? 0) + totalRuns;
                 if (totalRuns >= 4 && resultType == 'boundary') batting[sIdx]['fours'] = (batting[sIdx]['fours'] ?? 0) + 1;
                 if (totalRuns == 6) batting[sIdx]['sixes'] = (batting[sIdx]['sixes'] ?? 0) + 1;
               }
               if (bIdx != -1) {
                 bowling[bIdx]['runs'] = (bowling[bIdx]['runs'] ?? 0) + totalRuns;
               }
            } else if (ballType == 'nb_extra') {
               final nbPenalty = 1;
               currentScore['runs'] = (currentScore['runs'] ?? 0) + nbPenalty; // Already added totalRuns above
               currentInn['extras']['noBalls'] = (currentInn['extras']['noBalls'] ?? 0) + totalRuns + nbPenalty;
               if (bIdx != -1) bowling[bIdx]['runs'] = (bowling[bIdx]['runs'] ?? 0) + nbPenalty;
            } else if (ballType == 'w') {
               final widePenalty = 1;
               currentScore['runs'] = (currentScore['runs'] ?? 0) + widePenalty;
               currentInn['extras']['wides'] = (currentInn['extras']['wides'] ?? 0) + totalRuns + widePenalty;
               if (bIdx != -1) bowling[bIdx]['runs'] = (bowling[bIdx]['runs'] ?? 0) + widePenalty;
            } else if (['b', 'lb'].contains(ballType)) {
               if (ballType == 'b') currentInn['extras']['byes'] = (currentInn['extras']['byes'] ?? 0) + totalRuns;
               else currentInn['extras']['legByes'] = (currentInn['extras']['legByes'] ?? 0) + totalRuns;
            }

            List<dynamic> thisOver = List.from(currentScore['thisOver'] ?? []);
            if (thisOver.isNotEmpty) {
               var last = thisOver.last.toString();
               // Precision: Overthrow Modifies EXISTING ball notation (Parity Upgrade)
               if (last.startsWith('NB')) {
                 int prev = int.parse(last.replaceAll(RegExp(r'[^0-9]'), ''));
                 thisOver[thisOver.length - 1] = 'NB${prev + totalRuns}';
               } else if (last.startsWith('WD')) {
                 int prev = int.parse(last.replaceAll(RegExp(r'[^0-9]'), ''));
                 thisOver[thisOver.length - 1] = 'WD${prev + totalRuns}';
               } else if (RegExp(r'^\d+$').hasMatch(last)) {
                 thisOver[thisOver.length - 1] = (int.parse(last) + totalRuns).toString();
               } else {
                 thisOver[thisOver.length - 1] = '$last+$totalRuns';
               }
               currentScore['thisOver'] = thisOver;
            }
            break;
            
          case 'new_bowler':
            currentMatch['currentBowler'] = value;
            currentScore['bowler'] = value;
            break;
        }
        
        // --- Global Stats Sync (Parity Upgrade) ---
        for (var p in batting) {
          final pRuns = p['runs'] ?? 0;
          final pBalls = p['balls'] ?? 0;
          if (pBalls > 0) {
            p['strikeRate'] = double.parse(((pRuns / pBalls) * 100.0).toStringAsFixed(2));
          }
        }

        for (var b in bowling) {
          final bOvers = double.tryParse(b['overs']?.toString() ?? '0.0') ?? 0.0;
          final totalBalls = oversToBalls(bOvers);
          if (totalBalls > 0) {
            b['economy'] = double.parse(((b['runs'] / (totalBalls / 6.0))).toStringAsFixed(2));
          }
        }
        
        currentInn['batting'] = batting;
        currentBowlInn['bowling'] = bowling;
        innings[battingTeamIdx] = currentInn;
        innings[bowlingTeamIdx] = currentBowlInn;
        
        payload = {'score': currentScore, 'innings': innings, 'history': match['history']};
      }

      // Use dedicated /score endpoint (Phase 25 Parity)
      final updated = await ApiService.updateScore(match['_id'] ?? match['id'], payload);
      setState(() {
        match = updated;
        isUpdating = false;
      });
    } catch (e) {
      setState(() => isUpdating = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: ${e.toString().replaceAll('Exception: ', '')}')));
    }
  }

  Future<void> _handleTossUpdate(String winnerId, String decision) async {
    setState(() => isUpdating = true);
    try {
      // Use dedicated /toss endpoint (Phase 25 Parity)
      final updated = await ApiService.updateToss(match['_id'] ?? match['id'], winnerId, decision);
      setState(() {
        match = updated;
        isUpdating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Toss updated successfully')));
    } catch (e) {
      setState(() => isUpdating = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Toss failed: ${e.toString().replaceAll('Exception: ', '')}')));
    }
  }

  void _advanceBall(Map<String, dynamic> score, Map<String, dynamic>? bowler, bool isExtraUncounted) {
    if (isExtraUncounted) return;
    
    // Total Match Overs
    double currentOvers = double.tryParse(score['overs']?.toString() ?? '0.0') ?? 0.0;
    int totalMatchBalls = oversToBalls(currentOvers) + 1;
    if (totalMatchBalls % 6 == 0) {
      score['thisOver'] = [];
    }
    score['overs'] = ballsToOvers(totalMatchBalls).toStringAsFixed(1);
    
    // Total Bowler Overs
    if (bowler != null) {
      double currentBOvers = double.tryParse(bowler['overs']?.toString() ?? '0.0') ?? 0.0;
      int totalBowlerBalls = oversToBalls(currentBOvers) + 1;
      bowler['overs'] = ballsToOvers(totalBowlerBalls).toStringAsFixed(1);
    }
  }

  void _logBall(Map<String, dynamic> score, String log) {
    List<dynamic> thisOver = List.from(score['thisOver'] ?? []);
    thisOver.add(log);
    score['thisOver'] = thisOver;
  }

  Future<void> _handleUndo() async {
    setState(() => isUpdating = true);
    try {
      final updated = await ApiService.reverseMatch(match['id'] ?? match['_id']);
      setState(() { match = updated; isUpdating = false; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Last action reversed')));
    } catch (e) {
      setState(() => isUpdating = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Undo failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final score = match['score'] ?? {};
    final bool isPaused = score['isPaused'] ?? false;
    final bool isCompleted = match['status'] == 'completed';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(
          '${match['teamA']} vs ${match['teamB']}'.toUpperCase(),
          style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.black, fontSize: 16),
        ),
        actions: [
            const Center(child: Padding(padding: EdgeInsets.only(right: 16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
            onPressed: () => PdfService.generateScorecard(match),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildStickyHeader(score),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildTossBanner(),
                  _buildScoringGrid(isPaused, isCompleted),
                  const SizedBox(height: 24),
                  _buildAdvancedCorrectionPanel(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStickyHeader(Map<String, dynamic> score) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))],
      ),
      child: Column(
        children: [
          Text(
            (score['battingTeam'] ?? 'Team').toString().toUpperCase(),
            style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.blueAccent, fontSize: 14, letterSpacing: 1),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${score['runs'] ?? 0}',
                style: GoogleFonts.outfit(fontSize: 64, fontWeight: FontWeight.w900, color: const Color(0xFF1E293B)),
              ),
              Text(
                ' / ${score['wickets'] ?? 0}',
                style: GoogleFonts.outfit(fontSize: 40, fontWeight: FontWeight.w900, color: const Color(0xFF64748B)),
              ),
            ],
          ),
          Text(
            '(${score['overs'] ?? 0.0} OVERS)',
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade500),
          ),
          if (score['target'] != null)
             Container(
               margin: const EdgeInsets.only(top: 12),
               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
               decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(100)),
               child: Text('TARGET: ${score['target']}', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.redAccent, fontSize: 13)),
             ),
        ],
      ),
    );
  }

  Widget _buildTossBanner() {
    final toss = match['toss'] ?? {};
    if (toss['winner'] == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.stars, color: Colors.amber, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${toss['winner']} won the toss & elected to ${toss['decision']}'.toUpperCase(),
              style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.amber.shade900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoringGrid(bool isPaused, bool isCompleted) {
    return Column(
      children: [
        // ROW 1 – MATCH CONTROLS
        Row(
          children: [
            _controlButton('SQUADS', Icons.groups, Colors.blue, () {}),
            const SizedBox(width: 8),
            _controlButton('DLS', Icons.cloud, Colors.indigo, _showDlsModal),
            const SizedBox(width: 8),
            _controlButton('REVERSE', Icons.history, Colors.orange, _handleUndo),
            const SizedBox(width: 8),
            _controlButton(
                isPaused ? 'RESUME' : 'PAUSE',
                isPaused ? Icons.play_circle_filled : Icons.pause_circle_filled,
                isPaused ? Colors.green : Colors.red,
                () => _handlePauseToggle(!isPaused)
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ROW 2 – PRIMARY SCORING
        Row(
            children: [
                _scoreBtn('0', () => _handleUpdate('runs', value: 0)),
                const SizedBox(width: 8),
                _scoreBtn('1', () => _handleUpdate('runs', value: 1)),
                const SizedBox(width: 8),
                _scoreBtn('2', () => _handleUpdate('runs', value: 2)),
                const SizedBox(width: 8),
                _scoreBtn('3', () => _handleUpdate('runs', value: 3)),
                const SizedBox(width: 8),
                _scoreBtn('4', () => _handleUpdate('runs', value: 4)),
                const SizedBox(width: 8),
                _scoreBtn('6', () => _handleUpdate('runs', value: 6)),
                const SizedBox(width: 8),
                _scoreBtn('WKT', () => _showWicketModal(), isWicket: true),
            ]
        ),
        const SizedBox(height: 16),

        // ROW 3 – EXTRAS
        Row(
            children: [
                _extraBtn('WIDE', () => _showExtrasModal('wd')),
                const SizedBox(width: 8),
                _extraBtn('NO BALL', () => _showExtrasModal('nb')),
                const SizedBox(width: 8),
                _extraBtn('LEG BYE', () => _showExtrasModal('lb')),
                const SizedBox(width: 8),
                _extraBtn('BYE', () => _showExtrasModal('b')),
                const SizedBox(width: 8),
                _extraBtn('O/THROW', () => _showOverthrowModal()),
            ]
        ),
        const SizedBox(height: 16),

        // ROW 4 – PLAYER ACTIONS
        Row(
            children: [
                _actionBtn('CHANGE STRIKE', Icons.swap_calls, () => _handleUpdate('swap')),
                const SizedBox(width: 8),
                _actionBtn('RETIRE BATTER', Icons.exit_to_app, () {}),
                const SizedBox(width: 8),
                _actionBtn('REPLACE BOWLER', Icons.psychology, () => _showBowlerReplacementModal()),
            ]
        ),
        const SizedBox(height: 16),

        // ROW 5 – STATE INDICATOR
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: (match['score']?['freeHit'] ?? false) ? Colors.red.shade600 : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(16),
            boxShadow: (match['score']?['freeHit'] ?? false) ? [BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))] : [],
          ),
          child: Center(
            child: Text(
              (match['score']?['freeHit'] ?? false) ? 'FREE HIT ON' : 'FREE HIT OFF',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: (match['score']?['freeHit'] ?? false) ? Colors.white : Colors.grey.shade500, letterSpacing: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAdvancedCorrectionPanel() {
    return ExpansionTile(
      title: Text('ADVANCED CORRECTION PANEL', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.blueGrey)),
      subtitle: Text('Manual state overrides & technical fixes', style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey)),
      children: [
         Padding(
           padding: const EdgeInsets.all(16.0),
           child: Column(
             children: [
                _buildManualInput('Runs', (val) => _handleManualUpdate('runs', val)),
                _buildManualInput('Wickets', (val) => _handleManualUpdate('wickets', val)),
                _buildManualInput('Overs', (val) => _handleManualUpdate('overs', val)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _dangerBtn('FORCE END', () => _handleAdvancedAction('force_end'))),
                    const SizedBox(width: 8),
                    Expanded(child: _dangerBtn('CLEAR LOG', () => _handleAdvancedAction('clear_log'))),
                    const SizedBox(width: 8),
                    Expanded(child: _dangerBtn('PURGE HIST', () => _handleAdvancedAction('purge_history'))),
                  ],
                )
             ],
           ),
         )
      ],
    );
  }

  // Helper methods for buttons to match premium aesthetics
  Widget _controlButton(String label, IconData icon, Color color, VoidCallback? onPressed) {
    return Expanded(
      child: InkWell(
        onTap: isUpdating ? null : onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3))),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 4),
              Text(label, style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.w900, color: color)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scoreBtn(String label, VoidCallback onPressed, {bool isWicket = false}) {
    final color = isWicket ? Colors.red : Colors.blue;
    return Expanded(
      child: ElevatedButton(
        onPressed: (isUpdating || (match['score']?['isPaused'] ?? false)) ? null : onPressed,
        style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: color,
            elevation: 2,
            shadowColor: color.withOpacity(0.2),
            padding: const EdgeInsets.symmetric(vertical: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: color.withOpacity(0.5)))),
        child: Text(label, style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16)),
      ),
    );
  }

  Widget _extraBtn(String label, VoidCallback onPressed) {
    return Expanded(
      child: ElevatedButton(
        onPressed: (isUpdating || (match['score']?['isPaused'] ?? false)) ? null : onPressed,
        style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber.shade50,
            foregroundColor: Colors.amber.shade900,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.amber.shade200))),
        child: Text(label, style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 8)),
      ),
    );
  }

  Widget _actionBtn(String label, IconData icon, VoidCallback onPressed) {
    return Expanded(
      child: ElevatedButton.icon(
        onPressed: (isUpdating || (match['score']?['isPaused'] ?? false)) ? null : onPressed,
        icon: Icon(icon, size: 14),
        label: Text(label, style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 8)),
        style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF1F5F9),
            foregroundColor: const Color(0xFF475569),
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
      ),
    );
  }

  Widget _dangerBtn(String label, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: isUpdating ? null : onPressed,
      style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade50, foregroundColor: Colors.red.shade700, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
      child: Text(label, style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 9)),
    );
  }

  Widget _buildManualInput(String label, Function(String) onSave) {
     final controller = TextEditingController();
     return Padding(
       padding: const EdgeInsets.only(bottom: 8.0),
       child: Row(
         children: [
            Expanded(flex: 2, child: Text(label, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold))),
            Expanded(flex: 3, child: SizedBox(height: 35, child: TextField(controller: controller, keyboardType: label == 'Overs' ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.number, style: const TextStyle(fontSize: 12), decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8))))),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => onSave(controller.text),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)),
              child: Text('SAVE', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold))
            )
         ],
       ),
     );
  }

  void _showWicketModal() {
    final List<String> wicketTypes = ['Bowled', 'Caught', 'LBW', 'Stumped', 'Run Out', 'Hit Wicket', 'Retired'];
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32))),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('OUT!', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.red, letterSpacing: 2)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: wicketTypes.map((type) => ElevatedButton(
                onPressed: () {
                   Navigator.pop(context);
                   _handleUpdate('wicket', value: type);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade50,
                  foregroundColor: Colors.red.shade900,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(type.toUpperCase(), style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 10)),
              )).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showOverthrowModal() {
    if ((match['score']?['thisOver'] as List?)?.isEmpty ?? true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Overthrow only allowed after a base delivery!')));
      return;
    }

    String ballType = 'normal';
    int runsCompleted = 0;
    bool crossedOnThrow = false;
    String resultType = 'boundary';
    int manualRuns = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32))),
          padding: EdgeInsets.only(left: 32, right: 32, top: 32, bottom: MediaQuery.of(context).viewInsets.bottom + 32),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Text('⚡ RECORD OVERTHROW', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: const Color(0xFF1E293B)))),
                const SizedBox(height: 24),
                
                Text('BALL TYPE', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.5)),
                DropdownButton<String>(
                  value: ballType,
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: [
                    {'l': 'Normal Ball', 'v': 'normal'},
                    {'l': 'Wide Ball', 'v': 'w'},
                    {'l': 'No Ball (Bat)', 'v': 'nb'},
                    {'l': 'No Ball (Extra)', 'v': 'nb_extra'},
                    {'l': 'Bye', 'v': 'b'},
                    {'l': 'Leg Bye', 'v': 'lb'},
                  ].map((e) => DropdownMenuItem(value: e['v'], child: Text(e['l']!, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)))).toList(),
                  onChanged: (v) => setModalState(() => ballType = v!),
                ),
                const Divider(),
                
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('RUNS COMPLETED', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.5)),
                          TextField(
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(border: InputBorder.none, hintText: '0'),
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                            onChanged: (v) => runsCompleted = int.tryParse(v) ?? 0,
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: crossedOnThrow,
                      onChanged: (v) => setModalState(() => crossedOnThrow = v),
                    ),
                    Text('CROSSED', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey)),
                  ],
                ),
                const Divider(),

                Text('OVERTHROW RESULT', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.5)),
                Row(
                  children: [
                    Radio<String>(value: 'boundary', groupValue: resultType, onChanged: (v) => setModalState(() => resultType = v!)),
                    Text('Boundary (+4)', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 16),
                    Radio<String>(value: 'manual', groupValue: resultType, onChanged: (v) => setModalState(() => resultType = v!)),
                    Text('Manual', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                  ],
                ),
                
                if (resultType == 'manual')
                  TextField(
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Manual Overthrow Runs',
                      labelStyle: GoogleFonts.outfit(fontSize: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: (v) => manualRuns = int.tryParse(v) ?? 0,
                  ),
                
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _handleUpdate('overthrow', value: {
                        'ballType': ballType,
                        'runsCompleted': runsCompleted,
                        'crossedOnThrow': crossedOnThrow,
                        'resultType': resultType,
                        'manualRuns': manualRuns,
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text('RECORD OVERTHROW', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showBowlerReplacementModal() {
    final score = match['score'] ?? {};
    final thisOver = score['thisOver'] as List? ?? [];
    final legalBalls = thisOver.where((b) => !b.toString().toUpperCase().contains('WD') && !b.toString().toUpperCase().contains('NB')).length;
    final remaining = 6 - legalBalls;

    if (remaining > 0 && thisOver.isNotEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(
         content: Text('🩹 Bowler replaced due to injury. $remaining balls remaining.'),
         backgroundColor: Colors.orange,
         duration: const Duration(seconds: 4),
       ));
    }

    final battingTeam = match['score']?['battingTeam'];
    final bowlingSquad = battingTeam == match['teamA'] ? (match['squadB'] as List? ?? []) : (match['squadA'] as List? ?? []);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32))),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('⚾ REPLACE BOWLER', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 24),
            ...bowlingSquad.where((p) => p.toString().trim().isNotEmpty).map((p) => ListTile(
              title: Text(p.toString().toUpperCase(), style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context);
                _handleUpdate('new_bowler', value: p);
              },
            )).toList(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showDlsModal() {
    final targetController = TextEditingController(text: (match['score']?['target'] ?? '').toString());
    final oversController = TextEditingController(text: (match['totalOvers'] ?? '').toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32))),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('🌧️ DLS ADJUSTMENTS', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.indigo)),
              const SizedBox(height: 24),
              Text('REVISED TARGET SCORE', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
              const SizedBox(height: 8),
              TextField(
                controller: targetController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Enter new target',
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              Text('REVISED TOTAL OVERS', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
              const SizedBox(height: 8),
              TextField(
                controller: oversController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Enter new total overs',
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100))),
                      child: Text('CANCEL', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (targetController.text.isEmpty || oversController.text.isEmpty) return;
                        final updatedMatch = Map<String, dynamic>.from(match);
                        updatedMatch['totalOvers'] = int.tryParse(oversController.text) ?? updatedMatch['totalOvers'];
                        final score = Map<String, dynamic>.from(updatedMatch['score'] ?? {});
                        score['target'] = int.tryParse(targetController.text) ?? score['target'];
                        updatedMatch['score'] = score;
                        updatedMatch['isDLS'] = true;
                        
                        Navigator.pop(context);
                        _handleUpdate('manual', value: updatedMatch);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                      ),
                      child: Text('APPLY DLS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handlePauseToggle(bool pause) async {
    final List<String> reasons = ['Rain', 'Bad Light', 'Innings Break', 'Injury', 'Other'];
    String? selectedReason;

    if (pause) {
      selectedReason = await showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
          title: Text('Select Pause Reason', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          children: reasons.map((r) => SimpleDialogOption(
            onPressed: () => Navigator.pop(context, r),
            child: Text(r, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          )).toList(),
        ),
      );
      if (selectedReason == null) return;
    }

    setState(() => isUpdating = true);
    try {
      final updated = await ApiService.pauseMatch(match['id'] ?? match['_id'], pause, selectedReason ?? '');
      setState(() { match = updated; isUpdating = false; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(pause ? 'Match Paused' : 'Match Resumed')));
    } catch (e) {
      setState(() => isUpdating = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pause failed: $e')));
    }
  }
  
  void _handleManualUpdate(String field, String value) async {
      if (value.isEmpty) return;
      final currentScore = Map<String, dynamic>.from(match['score'] ?? {});
      
      if (field == 'runs') currentScore['runs'] = int.tryParse(value) ?? currentScore['runs'];
      if (field == 'wickets') currentScore['wickets'] = int.tryParse(value) ?? currentScore['wickets'];
      if (field == 'overs') currentScore['overs'] = value;

      _handleUpdate('manual', value: {'score': currentScore});
  }

  Future<void> _handleAdvancedAction(String action) async {
      // Implement Force End, Clear Log, Purge Hist logic
      String confirmMsg = '';
      Map<String, dynamic> payload = {};
      final currentScore = Map<String, dynamic>.from(match['score'] ?? {});

      if (action == 'force_end') {
          confirmMsg = 'Force end this innings?';
          currentScore['overs'] = match['totalOvers'] ?? 20;
          payload = {'score': currentScore};
      } else if (action == 'clear_log') {
          confirmMsg = 'Clear the current over log?';
          currentScore['thisOver'] = [];
          payload = {'score': currentScore};
      } else if (action == 'purge_history') {
          confirmMsg = 'Purge ALL match history? This cannot be undone.';
          payload = {'history': []};
      }

      final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
              title: const Text('Are you sure?'),
              content: Text(confirmMsg),
              actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
                  TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('YES, DO IT', style: TextStyle(color: Colors.red))),
              ],
          )
      );

      if (confirmed == true) {
          _handleUpdate('manual', value: payload);
      }
  }

  void _showExtrasModal(String type) {
    int extraRuns = 0;
    bool isBat = false;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32))),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${type.toUpperCase()} BALL', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, color: const Color(0xFF1E293B))),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [0, 1, 2, 4, 6].map((r) => GestureDetector(
                  onTap: () => setModalState(() => extraRuns = r),
                  child: Container(
                    width: 50, height: 50,
                    decoration: BoxDecoration(
                      color: extraRuns == r ? const Color(0xFF2563EB) : Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(r.toString(), style: GoogleFonts.outfit(color: extraRuns == r ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
                  ),
                )).toList(),
              ),
              if (type == 'nb') ...[
                const SizedBox(height: 20),
                CheckboxListTile(
                  title: Text('Hit by Bat', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                  value: isBat,
                  onChanged: (v) => setModalState(() => isBat = v ?? false),
                ),
              ],
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _handleUpdate('extra', value: type, params: {'amount': extraRuns + 1, 'isBat': isBat});
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text('RECORD EXTRA', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _extraBtn(String label, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.orange.shade50,
        foregroundColor: Colors.orange.shade900,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.orange.shade100)),
      ),
      child: Text(label, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }
}
