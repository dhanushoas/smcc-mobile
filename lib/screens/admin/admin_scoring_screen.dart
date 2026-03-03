import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../services/api_service.dart';
import '../../core/scoring/scoring_engine.dart';
import '../../core/scoring/match_state.dart';
import '../../core/scoring/scoring_enums.dart';

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
            Navigator.of(context).popUntil((route) => route.isFirst);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Logged out: Session active on another platform')));
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
        // Stripping toss to isolate scoring logic (Phase 25 Parity)
        currentMatch.remove('toss');
        
        final currentScore = Map<String, dynamic>.from(match['score'] ?? {});
        
        switch (type) {
          case 'runs':
            final runs = value as int;
            currentScore['runs'] = (currentScore['runs'] ?? 0) + runs;
            _advanceBall(currentScore, false);
            _logBall(currentScore, runs.toString());
            break;
          case 'extra':
            final extraType = value as String;
            final amount = params?['amount'] ?? 1;
            currentScore['runs'] = (currentScore['runs'] ?? 0) + amount + (['w', 'nb'].contains(extraType) ? 1 : 0);
            _advanceBall(currentScore, ['w', 'nb'].contains(extraType));
            _logBall(currentScore, '${extraType.toUpperCase()}$amount');
            break;
          case 'wicket':
            currentScore['wickets'] = (currentScore['wickets'] ?? 0) + 1;
            _advanceBall(currentScore, false);
            _logBall(currentScore, 'W');
            break;
          case 'swap':
            // Strike swap logic
            break;
        }
        payload = {'score': currentScore, 'innings': match['innings'], 'history': match['history']};
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

  void _advanceBall(Map<String, dynamic> score, bool isExtraUncounted) {
    if (isExtraUncounted) return; // Wides/No balls don't advance the over
    double overs = double.tryParse(score['overs']?.toString() ?? '0.0') ?? 0.0;
    int whole = overs.floor();
    int balls = ((overs - whole) * 10).round();
    
    balls++;
    if (balls >= 6) {
      whole++;
      balls = 0;
      score['thisOver'] = []; // Clear log on over completion
    }
    score['overs'] = '$whole.$balls';
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
          if (isUpdating)
            const Center(child: Padding(padding: EdgeInsets.only(right: 16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))),
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
            _controlButton('DLS', Icons.cloud, Colors.indigo, () {}),
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
                _actionBtn('REPLACE BOWLER', Icons.psychology, () {}),
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32))),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('OVERTHROW RUNS', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [1, 2, 3, 4].map((runs) => ElevatedButton(
                onPressed: () {
                   Navigator.pop(context);
                   _handleUpdate('overthrow', value: runs);
                },
                style: ElevatedButton.styleFrom(minimumSize: const Size(60,60), shape: const CircleBorder()),
                child: Text('+$runs', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18)),
              )).toList(),
            ),
          ],
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
}
