import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../services/api_service.dart';
import '../../core/scoring/scoring_engine.dart';
import '../../core/scoring/match_state.dart';
import '../../core/scoring/scoring_enums.dart';
import '../../services/pdf_service.dart';
import '../../services/auth_service.dart';
import '../../utils/calculations.dart';
import '../../utils/formatters.dart' hide oversToBalls, ballsToOvers;

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

  // Checkbox states for delivery type
  bool _isWideChecked = false;
  bool _isNbChecked = false;
  bool _isByesChecked = false;
  bool _isLbChecked = false;
  bool _isWicketChecked = false;

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
      if (mounted) {
        final updated = Map<String, dynamic>.from(data);
        final currentId = (match['_id'] ?? match['id']).toString();
        final updatedId = (updated['_id'] ?? updated['id']).toString();
        if (updatedId == currentId) {
          setState(() => match = updated);
        }
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
        
        // --- MATCH SETUP VALIDATION (Parity upgrade) ---
        final squadA = List.from(match['squadA'] ?? []);
        final squadB = List.from(match['squadB'] ?? []);
        if (squadA.isEmpty || squadB.isEmpty) {
          if (mounted) {
            setState(() => isUpdating = false);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select squads before starting the match.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red));
          }
          return;
        }

        final toss = match['toss'] ?? {};
        if (toss['winner'] == null || toss['decision'] == null) {
          if (mounted) {
            setState(() => isUpdating = false);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Conduct toss before starting the match.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red));
          }
          return;
        }

        if (innings.isEmpty) {
           if (mounted) {
             setState(() => isUpdating = false);
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Start innings first.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red));
           }
           return;
        }

        final strikerName = currentScore['striker'];
        final bowlerName = currentScore['bowler'];
        final nonStrikerName = currentScore['nonStriker'];
        
        // Bypassing player validation for pure 'swap' logic or 'new_bowler' selection itself
        if (type != 'swap' && type != 'retire' && type != 'new_bowler') {
          if (strikerName == null || bowlerName == null) {
             if (mounted) {
               setState(() => isUpdating = false);
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select players before scoring', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red));
             }
             return;
          }
        }
        // -----------------------------------------------

        final String battingTeamName = currentScore['battingTeam'].toString();
        final int battingTeamIdx = innings.indexWhere((inn) => inn['team'].toString() == battingTeamName);
        if (battingTeamIdx == -1) {
            if (mounted) {
              setState(() => isUpdating = false);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('RangeError (length): Invalid value: Valid value range is empty: -1. Setup your innings!')));
            }
            return;
        }
        final int bowlingTeamIdx = battingTeamIdx == 0 ? 1 : 0;
        
        final currentInn = Map<String, dynamic>.from(innings[battingTeamIdx]);
        final currentBowlInn = Map<String, dynamic>.from(innings[bowlingTeamIdx]);
        
        final batting = List<Map<String, dynamic>>.from((currentInn['batting'] ?? []).map((e) => Map<String, dynamic>.from(e)));
        final bowling = List<Map<String, dynamic>>.from((currentBowlInn['bowling'] ?? []).map((e) => Map<String, dynamic>.from(e)));
        
        int sIdx = batting.indexWhere((p) => (p['player'] ?? '').toString() == strikerName.toString());
        int nsIdx = batting.indexWhere((p) => (p['player'] ?? '').toString() == nonStrikerName.toString());
        int bIdx = bowling.indexWhere((p) => (p['player'] ?? '').toString() == bowlerName.toString());
        
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
            final int runs = value is int ? value : int.tryParse(value.toString()) ?? 0;
            currentScore['runs'] = (int.tryParse(currentScore['runs']?.toString() ?? '0') ?? 0) + runs;
            if (sIdx != -1) {
              batting[sIdx]['runs'] = (int.tryParse(batting[sIdx]['runs']?.toString() ?? '0') ?? 0) + runs;
              batting[sIdx]['balls'] = (int.tryParse(batting[sIdx]['balls']?.toString() ?? '0') ?? 0) + 1;
              if (runs == 4) batting[sIdx]['fours'] = (int.tryParse(batting[sIdx]['fours']?.toString() ?? '0') ?? 0) + 1;
              if (runs == 6) batting[sIdx]['sixes'] = (int.tryParse(batting[sIdx]['sixes']?.toString() ?? '0') ?? 0) + 1;
            }
            if (bIdx != -1) bowling[bIdx]['runs'] = (int.tryParse(bowling[bIdx]['runs']?.toString() ?? '0') ?? 0) + runs;
            _advanceBall(currentScore, bIdx != -1 ? bowling[bIdx] : null, false);
            _logBall(currentScore, runs.toString());
            break;
            
          case 'extra':
            final String extraType = value.toString();
            final int amount = int.tryParse(params?['amount']?.toString() ?? '1') ?? 1;
            final bool isBOrLB = ['b', 'lb'].contains(extraType);
            final bool isWOrNB = ['w', 'nb'].contains(extraType);
            
            // Advanced settings
            final settings = currentScore['settings'] ?? {};
            final wideSettings = settings['wideBall'] ?? {'reBall': true, 'runs': 1};
            final nbSettings = settings['noBall'] ?? {'reBall': true, 'runs': 1};
            
            final int wideRunCost = int.tryParse(wideSettings['runs']?.toString() ?? '1') ?? 1;
            final int nbRunCost = int.tryParse(nbSettings['runs']?.toString() ?? '1') ?? 1;
            final bool wideReBall = wideSettings['reBall'] == true;
            final bool nbReBall = nbSettings['reBall'] == true;
            
            final int penalty = extraType == 'w' ? wideRunCost : (extraType == 'nb' ? nbRunCost : 0);
            
            currentScore['runs'] = (int.tryParse(currentScore['runs']?.toString() ?? '0') ?? 0) + amount;
            
            if (isBOrLB) {
               if (sIdx != -1) batting[sIdx]['balls'] = (int.tryParse(batting[sIdx]['balls']?.toString() ?? '0') ?? 0) + 1;
            }
            if (isWOrNB) {
               if (bIdx != -1) {
                 bowling[bIdx]['runs'] = (int.tryParse(bowling[bIdx]['runs']?.toString() ?? '0') ?? 0) + amount;
                 if (extraType == 'w') bowling[bIdx]['wides'] = (int.tryParse(bowling[bIdx]['wides']?.toString() ?? '0') ?? 0) + 1;
                 if (extraType == 'nb') bowling[bIdx]['noBalls'] = (int.tryParse(bowling[bIdx]['noBalls']?.toString() ?? '0') ?? 0) + 1;
               }
               if (extraType == 'nb' && params?['isBat'] == true) {
                 final int batterRuns = amount - penalty;
                 if (sIdx != -1 && batterRuns > 0) {
                   batting[sIdx]['runs'] = (int.tryParse(batting[sIdx]['runs']?.toString() ?? '0') ?? 0) + batterRuns;
                   batting[sIdx]['balls'] = (int.tryParse(batting[sIdx]['balls']?.toString() ?? '0') ?? 0) + 1;
                 }
               }
            }
            
            final bool isReBall = extraType == 'w' ? wideReBall : (extraType == 'nb' ? nbReBall : false);
            _advanceBall(currentScore, bIdx != -1 ? bowling[bIdx] : null, isReBall);
            
            String ballLog;
            if (extraType == 'w') {
                final int baseR = amount - penalty;
                ballLog = baseR > 0 ? 'W+$baseR' : 'W';
            } else if (extraType == 'nb') {
                final int baseR = amount - penalty;
                ballLog = baseR > 0 ? 'NB+$baseR' : 'NB';
            } else {
                ballLog = '${extraType.toUpperCase()}+$amount';
            }
            _logBall(currentScore, ballLog);
            break;
            
          case 'wicket':
            currentScore['wickets'] = (int.tryParse(currentScore['wickets']?.toString() ?? '0') ?? 0) + 1;
            if (sIdx != -1) {
              batting[sIdx]['balls'] = (int.tryParse(batting[sIdx]['balls']?.toString() ?? '0') ?? 0) + 1;
              batting[sIdx]['status'] = 'out';
              batting[sIdx]['wicketType'] = value.toString();
              batting[sIdx]['bowler'] = bowlerName;
            }
            if (bIdx != -1) bowling[bIdx]['wickets'] = (int.tryParse(bowling[bIdx]['wickets']?.toString() ?? '0') ?? 0) + 1;
            _advanceBall(currentScore, bIdx != -1 ? bowling[bIdx] : null, false);
            _logBall(currentScore, 'W');
            break;

          case 'swap':
            final temp = currentScore['striker'];
            currentScore['striker'] = currentScore['nonStriker'];
            currentScore['nonStriker'] = temp;
            break;

          case 'retire':
            if (sIdx != -1) {
              batting[sIdx]['status'] = 'retired';
            }
            currentScore['striker'] = null;
            break;

          case 'free_hit':
            currentScore['freeHit'] = value as bool;
            break;
            
          case 'overthrow':
            final data = value as Map<String, dynamic>;
            final ballType = data['ballType'].toString();
            final int runsCompleted = int.tryParse(data['runsCompleted']?.toString() ?? '0') ?? 0;
            final bool crossedOnThrow = data['crossedOnThrow'] == true;
            final resultType = data['resultType'].toString();
            final int manualRuns = int.tryParse(data['manualRuns']?.toString() ?? '0') ?? 0;
            
            final int overtimeRuns = resultType == 'boundary' ? 4 : manualRuns;
            final int baseRuns = (runsCompleted + (crossedOnThrow ? 1 : 0));
            final int totalRuns = baseRuns + overtimeRuns;
            
            currentScore['runs'] = (int.tryParse(currentScore['runs']?.toString() ?? '0') ?? 0) + totalRuns;
            if (ballType == 'normal' || ballType == 'nb') {
              if (sIdx != -1) batting[sIdx]['runs'] = (int.tryParse(batting[sIdx]['runs']?.toString() ?? '0') ?? 0) + totalRuns;
              if (bIdx != -1) bowling[bIdx]['runs'] = (int.tryParse(bowling[bIdx]['runs']?.toString() ?? '0') ?? 0) + totalRuns;
              
              if (ballType == 'nb') {
                currentScore['runs'] = (int.tryParse(currentScore['runs']?.toString() ?? '0') ?? 0) + 1;
                if (bIdx != -1) {
                  bowling[bIdx]['runs'] = (int.tryParse(bowling[bIdx]['runs']?.toString() ?? '0') ?? 0) + 1;
                  bowling[bIdx]['noBalls'] = (int.tryParse(bowling[bIdx]['noBalls']?.toString() ?? '0') ?? 0) + 1;
                }
                currentScore['freeHit'] = true;
                _logBall(currentScore, totalRuns > 0 ? 'NB+$totalRuns' : 'NB');
              } else {
                _logBall(currentScore, '$baseRuns+OV$overtimeRuns');
              }
            } else if (ballType == 'w') {
                currentScore['runs'] = (int.tryParse(currentScore['runs']?.toString() ?? '0') ?? 0) + 1;
                if (bIdx != -1) {
                  bowling[bIdx]['runs'] = (int.tryParse(bowling[bIdx]['runs']?.toString() ?? '0') ?? 0) + totalRuns + 1;
                  bowling[bIdx]['wides'] = (int.tryParse(bowling[bIdx]['wides']?.toString() ?? '0') ?? 0) + 1;
                }
                _logBall(currentScore, totalRuns > 0 ? 'W+$totalRuns' : 'W');
            } else if (ballType == 'b' || ballType == 'lb') {
                if (sIdx != -1) batting[sIdx]['balls'] = (int.tryParse(batting[sIdx]['balls']?.toString() ?? '0') ?? 0) + 1;
                _logBall(currentScore, '${ballType.toUpperCase()}+$totalRuns');
            }

            if (totalRuns % 2 != 0) {
              final temp = currentScore['striker'];
              currentScore['striker'] = currentScore['nonStriker'];
              currentScore['nonStriker'] = temp;
            }
            break;
            
          case 'new_bowler':
            currentMatch['currentBowler'] = value.toString();
            currentScore['bowler'] = value.toString();
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
        
        List<dynamic> historyLog = List.from(match['history'] ?? []);
        if (['runs', 'extra', 'wicket', 'swap', 'overthrow'].contains(type)) {
            final snapshot = Map<String, dynamic>.from(match);
            snapshot.remove('history');
            historyLog.add(snapshot);
        }
        
        payload = {'score': currentScore, 'innings': innings, 'history': historyLog};
      }

      final updated = await ApiService.updateScore((match['_id'] ?? match['id']).toString(), payload);
      if (mounted) {
        setState(() {
          match = updated;
          isUpdating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isUpdating = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: ${e.toString().replaceAll('Exception: ', '')}')));
      }
    }
  }

  Future<void> _handleTossUpdate(String winnerId, String decision) async {
    setState(() => isUpdating = true);
    try {
      // Use dedicated /toss endpoint (Phase 25 Parity)
      final updated = await ApiService.updateToss((match['_id'] ?? match['id']).toString(), winnerId, decision);
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))));
    }
  }

  // Helper to build a styled checkbox
  Widget _buildCheckbox(String label, bool value, ValueChanged<bool?> onChanged) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFF2E7D32),
        ),
        Text(label, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
      ],
    );
  }

  // Circular run button
  Widget _circleRunButton(String label, int runs) {
    return InkWell(
      onTap: () => _handleScoringClick(runs),
      borderRadius: BorderRadius.circular(100),
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: const Color(0xFF2E7D32), width: 2.5),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF2E7D32)),
          ),
        ),
      ),
    );
  }

  // Vertical action button helper
  Widget _actionVerticalButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 14),
        label: Text(label, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 1,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  // Handle run click taking checkboxes into account
  void _handleScoringClick(int runs) {
    if (_isWicketChecked) {
      _showWicketModalWithContext(runs);
    } else {
      if (_isWideChecked) {
        final settings = match['score']?['settings'] ?? {};
        final wideSettings = settings['wideBall'] ?? {'reBall': true, 'runs': 1};
        final int wideRunCost = int.tryParse(wideSettings['runs']?.toString() ?? '1') ?? 1;
        _handleUpdate('extra', value: 'w', params: {'amount': wideRunCost + runs});
      } else if (_isNbChecked) {
        final settings = match['score']?['settings'] ?? {};
        final nbSettings = settings['noBall'] ?? {'reBall': true, 'runs': 1};
        final int nbRunCost = int.tryParse(nbSettings['runs']?.toString() ?? '1') ?? 1;
        final bool isBat = !_isByesChecked && !_isLbChecked;
        _handleUpdate('extra', value: 'nb', params: {'amount': nbRunCost + runs, 'isBat': isBat});
      } else if (_isByesChecked) {
        _handleUpdate('extra', value: 'b', params: {'amount': runs});
      } else if (_isLbChecked) {
        _handleUpdate('extra', value: 'lb', params: {'amount': runs});
      } else {
        _handleUpdate('runs', value: runs);
      }
      
      // Reset checkboxes
      setState(() {
        _isWideChecked = false;
        _isNbChecked = false;
        _isByesChecked = false;
        _isLbChecked = false;
        _isWicketChecked = false;
      });
    }
  }

  void _showCustomRunsDialog() {
    final runsController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('CUSTOM RUNS', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: runsController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Runs completed', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          TextButton(
            onPressed: () {
              final int r = int.tryParse(runsController.text) ?? 0;
              Navigator.pop(context);
              _handleScoringClick(r);
            },
            child: const Text('SUBMIT'),
          ),
        ],
      ),
    );
  }

  void _showWicketModalWithContext(int runs) {
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
                   setState(() {
                     _isWideChecked = false;
                     _isNbChecked = false;
                     _isByesChecked = false;
                     _isLbChecked = false;
                     _isWicketChecked = false;
                   });
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

  // Dynamic Partnership Calculation
  Map<String, dynamic> calculatePartnership() {
    final score = match['score'] ?? {};
    final striker = score['striker'];
    final nonStriker = score['nonStriker'];
    
    if (striker == null || nonStriker == null) {
      return {'runs': 0, 'balls': 0, 'strikerRuns': 0, 'strikerBalls': 0, 'nonStrikerRuns': 0, 'nonStrikerBalls': 0, 'extras': 0};
    }
    
    final history = match['history'] as List? ?? [];
    final currentWickets = score['wickets'] ?? 0;
    
    Map<String, dynamic>? lastWicketState;
    for (int i = history.length - 1; i >= 0; i--) {
      final state = history[i];
      final stateWickets = state['score']?['wickets'] ?? 0;
      if (stateWickets < currentWickets) {
        lastWicketState = state;
        break;
      }
    }
    
    int startStrikerRuns = 0;
    int startStrikerBalls = 0;
    int startNonStrikerRuns = 0;
    int startNonStrikerBalls = 0;
    int startExtras = 0;
    
    if (lastWicketState != null) {
      final lastScore = lastWicketState['score'] ?? {};
      final battingTeamName = lastScore['battingTeam'];
      final innings = lastWicketState['innings'] as List? ?? [];
      final battingTeamIdx = innings.indexWhere((inn) => inn['team'] == battingTeamName);
      if (battingTeamIdx != -1) {
        final batting = innings[battingTeamIdx]['batting'] as List? ?? [];
        final sRow = batting.firstWhere((p) => p['player'] == striker, orElse: () => null);
        final nsRow = batting.firstWhere((p) => p['player'] == nonStriker, orElse: () => null);
        startStrikerRuns = sRow?['runs'] ?? 0;
        startStrikerBalls = sRow?['balls'] ?? 0;
        startNonStrikerRuns = nsRow?['runs'] ?? 0;
        startNonStrikerBalls = nsRow?['balls'] ?? 0;
        startExtras = innings[battingTeamIdx]['extras']?['total'] ?? 0;
      }
    }
    
    final battingTeamName = score['battingTeam'];
    final currentInningsList = match['innings'] as List? ?? [];
    final currentBattingTeamIdx = currentInningsList.indexWhere((inn) => inn['team'] == battingTeamName);
    
    int currentStrikerRuns = 0;
    int currentStrikerBalls = 0;
    int currentNonStrikerRuns = 0;
    int currentNonStrikerBalls = 0;
    int currentExtras = 0;
    
    if (currentBattingTeamIdx != -1) {
      final batting = currentInningsList[currentBattingTeamIdx]['batting'] as List? ?? [];
      final sRow = batting.firstWhere((p) => p['player'] == striker, orElse: () => null);
      final nsRow = batting.firstWhere((p) => p['player'] == nonStriker, orElse: () => null);
      currentStrikerRuns = sRow?['runs'] ?? 0;
      currentStrikerBalls = sRow?['balls'] ?? 0;
      currentNonStrikerRuns = nsRow?['runs'] ?? 0;
      currentNonStrikerBalls = nsRow?['balls'] ?? 0;
      currentExtras = currentInningsList[currentBattingTeamIdx]['extras']?['total'] ?? 0;
    }
    
    final pStrikerRuns = currentStrikerRuns - startStrikerRuns;
    final pStrikerBalls = currentStrikerBalls - startStrikerBalls;
    final pNonStrikerRuns = currentNonStrikerRuns - startNonStrikerRuns;
    final pNonStrikerBalls = currentNonStrikerBalls - startNonStrikerBalls;
    final pExtras = currentExtras - startExtras;
    
    final pRuns = pStrikerRuns + pNonStrikerRuns + pExtras;
    final pBalls = pStrikerBalls + pNonStrikerBalls;
    
    return {
      'runs': pRuns,
      'balls': pBalls,
      'strikerRuns': pStrikerRuns,
      'strikerBalls': pStrikerBalls,
      'nonStrikerRuns': pNonStrikerRuns,
      'nonStrikerBalls': pNonStrikerBalls,
      'extras': pExtras
    };
  }

  void _showPartnershipsModal() {
    final score = match['score'] ?? {};
    final striker = score['striker'];
    final nonStriker = score['nonStriker'];
    if (striker == null || nonStriker == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select batsmen first!')));
      return;
    }
    
    final pData = calculatePartnership();
    
    final strikerRunsController = TextEditingController(text: pData['strikerRuns'].toString());
    final strikerBallsController = TextEditingController(text: pData['strikerBalls'].toString());
    final nonStrikerRunsController = TextEditingController(text: pData['nonStrikerRuns'].toString());
    final nonStrikerBallsController = TextEditingController(text: pData['nonStrikerBalls'].toString());
    final extrasController = TextEditingController(text: pData['extras'].toString());
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
          ),
          padding: EdgeInsets.only(left: 32, right: 32, top: 32, bottom: MediaQuery.of(context).viewInsets.bottom + 32),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('PARTNERSHIP DETAILS', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: const Color(0xFF2E7D32))),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text(striker.toString().toUpperCase(), style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.green.shade800), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 8),
                          TextField(
                            controller: strikerRunsController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Runs', border: OutlineInputBorder()),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: strikerBallsController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Balls', border: OutlineInputBorder()),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      children: [
                        Text(
                          '${int.tryParse(strikerRunsController.text) ?? 0} + ${int.tryParse(nonStrikerRunsController.text) ?? 0} + ${int.tryParse(extrasController.text) ?? 0}',
                          style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey),
                        ),
                        Text(
                          '${(int.tryParse(strikerRunsController.text) ?? 0) + (int.tryParse(nonStrikerRunsController.text) ?? 0) + (int.tryParse(extrasController.text) ?? 0)}',
                          style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.green),
                        ),
                        Text(
                          '(${(int.tryParse(strikerBallsController.text) ?? 0) + (int.tryParse(nonStrikerBallsController.text) ?? 0)} balls)',
                          style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        children: [
                          Text(nonStriker.toString().toUpperCase(), style: GoogleFonts.outfit(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 8),
                          TextField(
                            controller: nonStrikerRunsController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Runs', border: OutlineInputBorder()),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: nonStrikerBallsController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Balls', border: OutlineInputBorder()),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: extrasController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Extras', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('CANCEL', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          final int newSRuns = int.tryParse(strikerRunsController.text) ?? pData['strikerRuns'];
                          final int newSBalls = int.tryParse(strikerBallsController.text) ?? pData['strikerBalls'];
                          final int newNSRuns = int.tryParse(nonStrikerRunsController.text) ?? pData['nonStrikerRuns'];
                          final int newNSBalls = int.tryParse(nonStrikerBallsController.text) ?? pData['nonStrikerBalls'];
                          final int newExtras = int.tryParse(extrasController.text) ?? pData['extras'];
                          
                          final diffSRuns = newSRuns - pData['strikerRuns'];
                          final diffSBalls = newSBalls - pData['strikerBalls'];
                          final diffNSRuns = newNSRuns - pData['nonStrikerRuns'];
                          final diffNSBalls = newNSBalls - pData['nonStrikerBalls'];
                          final diffExtras = newExtras - pData['extras'];
                          
                          final updatedMatch = Map<String, dynamic>.from(match);
                          final currentScore = Map<String, dynamic>.from(updatedMatch['score'] ?? {});
                          final innings = List<Map<String, dynamic>>.from((updatedMatch['innings'] as List).map((e) => Map<String, dynamic>.from(e)));
                          
                          final String battingTeamName = currentScore['battingTeam'].toString();
                          final int battingTeamIdx = innings.indexWhere((inn) => inn['team'].toString() == battingTeamName);
                          
                          if (battingTeamIdx != -1) {
                            final currentInn = Map<String, dynamic>.from(innings[battingTeamIdx]);
                            final batting = List<Map<String, dynamic>>.from((currentInn['batting'] ?? []).map((e) => Map<String, dynamic>.from(e)));
                            final extras = Map<String, dynamic>.from(currentInn['extras'] ?? {});
                            
                            int sIdx = batting.indexWhere((p) => p['player'] == striker);
                            int nsIdx = batting.indexWhere((p) => p['player'] == nonStriker);
                            
                            if (sIdx != -1) {
                              batting[sIdx]['runs'] = (batting[sIdx]['runs'] ?? 0) + diffSRuns;
                              batting[sIdx]['balls'] = (batting[sIdx]['balls'] ?? 0) + diffSBalls;
                            }
                            if (nsIdx != -1) {
                              batting[nsIdx]['runs'] = (batting[nsIdx]['runs'] ?? 0) + diffNSRuns;
                              batting[nsIdx]['balls'] = (batting[nsIdx]['balls'] ?? 0) + diffNSBalls;
                            }
                            
                            extras['total'] = (extras['total'] ?? 0) + diffExtras;
                            currentInn['extras'] = extras;
                            
                            currentScore['runs'] = (currentScore['runs'] ?? 0) + diffSRuns + diffNSRuns + diffExtras;
                            
                            currentInn['batting'] = batting;
                            currentInn['runs'] = currentScore['runs'];
                            innings[battingTeamIdx] = currentInn;
                            
                            updatedMatch['score'] = currentScore;
                            updatedMatch['innings'] = innings;
                            
                            Navigator.pop(context);
                            _handleUpdate('manual', value: updatedMatch);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('UPDATE', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showExtrasBreakdownModal() {
    final score = match['score'] ?? {};
    final String battingTeamName = score['battingTeam']?.toString() ?? '';
    final innings = match['innings'] as List? ?? [];
    final battingTeamIdx = innings.indexWhere((inn) => inn['team'] == battingTeamName);
    
    if (battingTeamIdx == -1) return;
    
    final currentInn = innings[battingTeamIdx];
    final extras = currentInn['extras'] ?? {};
    
    final widesController = TextEditingController(text: (extras['wides'] ?? 0).toString());
    final noBallsController = TextEditingController(text: (extras['noBalls'] ?? 0).toString());
    final byesController = TextEditingController(text: (extras['byes'] ?? 0).toString());
    final legByesController = TextEditingController(text: (extras['legByes'] ?? 0).toString());
    
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
              Text('EXTRAS BREAKDOWN', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.amber.shade900)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: TextField(controller: widesController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Wides', border: OutlineInputBorder()))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: noBallsController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'No Balls', border: OutlineInputBorder()))),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: TextField(controller: byesController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Byes', border: OutlineInputBorder()))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: legByesController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Leg Byes', border: OutlineInputBorder()))),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100))),
                      child: Text('CANCEL', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final int newW = int.tryParse(widesController.text) ?? (extras['wides'] ?? 0);
                        final int newNb = int.tryParse(noBallsController.text) ?? (extras['noBalls'] ?? 0);
                        final int newB = int.tryParse(byesController.text) ?? (extras['byes'] ?? 0);
                        final int newLb = int.tryParse(legByesController.text) ?? (extras['legByes'] ?? 0);
                        
                        final int newTotal = newW + newNb + newB + newLb;
                        final int oldTotal = (extras['total'] ?? 0);
                        final int diff = newTotal - oldTotal;
                        
                        final updatedMatch = Map<String, dynamic>.from(match);
                        final currentScore = Map<String, dynamic>.from(updatedMatch['score'] ?? {});
                        final inningsList = List<Map<String, dynamic>>.from((updatedMatch['innings'] as List).map((e) => Map<String, dynamic>.from(e)));
                        
                        final currentInnMap = Map<String, dynamic>.from(inningsList[battingTeamIdx]);
                        final currentExtras = Map<String, dynamic>.from(currentInnMap['extras'] ?? {});
                        
                        currentExtras['wides'] = newW;
                        currentExtras['noBalls'] = newNb;
                        currentExtras['byes'] = newB;
                        currentExtras['legByes'] = newLb;
                        currentExtras['total'] = newTotal;
                        
                        currentInnMap['extras'] = currentExtras;
                        currentInnMap['runs'] = (currentInnMap['runs'] ?? 0) + diff;
                        inningsList[battingTeamIdx] = currentInnMap;
                        
                        currentScore['runs'] = (currentScore['runs'] ?? 0) + diff;
                        updatedMatch['score'] = currentScore;
                        updatedMatch['innings'] = inningsList;
                        
                        Navigator.pop(context);
                        _handleUpdate('manual', value: updatedMatch);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade900,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                      ),
                      child: Text('SAVE EXTRAS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
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

  void _showMatchSettingsModal() {
    final score = match['score'] ?? {};
    final settings = score['settings'] ?? {};
    final wideSettings = settings['wideBall'] ?? {'reBall': true, 'runs': 1};
    final nbSettings = settings['noBall'] ?? {'reBall': true, 'runs': 1};
    
    final playersController = TextEditingController(text: (settings['playersPerTeam'] ?? 11).toString());
    final wideRunsController = TextEditingController(text: (wideSettings['runs'] ?? 1).toString());
    final nbRunsController = TextEditingController(text: (nbSettings['runs'] ?? 1).toString());
    
    bool wideReBallVal = wideSettings['reBall'] == true;
    bool nbReBallVal = nbSettings['reBall'] == true;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32))),
            padding: const EdgeInsets.all(32),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Text('MATCH SETTINGS', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: const Color(0xFF2E7D32)))),
                  const SizedBox(height: 24),
                  
                  Text('PLAYERS PER TEAM', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: playersController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                  ),
                  
                  const SizedBox(height: 16),
                  Text('NO BALL CONFIGURATION', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.green.shade800)),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Re-ball No Ball?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                      Switch(
                        value: nbReBallVal,
                        onChanged: (val) => setModalState(() => nbReBallVal = val),
                        activeColor: const Color(0xFF2E7D32),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('No Ball Run Penalty Value', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nbRunsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                  ),
                  
                  const SizedBox(height: 20),
                  Text('WIDE BALL CONFIGURATION', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.green.shade800)),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Re-ball Wide Ball?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                      Switch(
                        value: wideReBallVal,
                        onChanged: (val) => setModalState(() => wideReBallVal = val),
                        activeColor: const Color(0xFF2E7D32),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Wide Ball Run Penalty Value', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: wideRunsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                  ),
                  
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100))),
                          child: Text('CANCEL', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            final int ppt = int.tryParse(playersController.text) ?? 11;
                            final int wRuns = int.tryParse(wideRunsController.text) ?? 1;
                            final int nRuns = int.tryParse(nbRunsController.text) ?? 1;
                            
                            final updatedMatch = Map<String, dynamic>.from(match);
                            final currentScore = Map<String, dynamic>.from(updatedMatch['score'] ?? {});
                            
                            currentScore['settings'] = {
                              'playersPerTeam': ppt,
                              'wideBall': {'reBall': wideReBallVal, 'runs': wRuns},
                              'noBall': {'reBall': nbReBallVal, 'runs': nRuns},
                            };
                            updatedMatch['score'] = currentScore;
                            
                            Navigator.pop(context);
                            _handleUpdate('manual', value: updatedMatch);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                          ),
                          child: Text('SAVE SETTINGS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScorerSetupCard() {
    final toss = match['toss'] ?? {};
    
    String? selectedTossWinner = toss['winner'];
    String? selectedDecision = toss['decision']?.toString().toUpperCase();
    final oversController = TextEditingController(text: (match['overs_per_match'] ?? match['totalOvers'] ?? 20).toString());
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              'SCORER SETUP',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF2E7D32)),
            ),
          ),
          const SizedBox(height: 20),
          
          Text('HOST TEAM', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
          const SizedBox(height: 6),
          Text(
            match['teamA']?.toString().toUpperCase() ?? '',
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const Divider(),
          
          Text('VISITOR TEAM', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
          const SizedBox(height: 6),
          Text(
            match['teamB']?.toString().toUpperCase() ?? '',
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const Divider(),
          
          const SizedBox(height: 12),
          Text('TOSS WINNER', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
          const SizedBox(height: 6),
          StatefulBuilder(
            builder: (context, setTossState) => Column(
              children: [
                Row(
                  children: [
                    Radio<String>(
                      value: match['teamA'],
                      groupValue: selectedTossWinner,
                      onChanged: (val) => setTossState(() => selectedTossWinner = val),
                      activeColor: const Color(0xFF2E7D32),
                    ),
                    Expanded(child: Text(match['teamA'] ?? '', style: GoogleFonts.outfit(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Radio<String>(
                      value: match['teamB'],
                      groupValue: selectedTossWinner,
                      onChanged: (val) => setTossState(() => selectedTossWinner = val),
                      activeColor: const Color(0xFF2E7D32),
                    ),
                    Expanded(child: Text(match['teamB'] ?? '', style: GoogleFonts.outfit(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ],
                ),
                
                const SizedBox(height: 12),
                Text('OPTED TO', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Radio<String>(
                      value: 'BAT',
                      groupValue: selectedDecision,
                      onChanged: (val) => setTossState(() => selectedDecision = val),
                      activeColor: const Color(0xFF2E7D32),
                    ),
                    Expanded(child: Text('BAT', style: GoogleFonts.outfit(fontWeight: FontWeight.bold))),
                    Radio<String>(
                      value: 'BOWL',
                      groupValue: selectedDecision,
                      onChanged: (val) => setTossState(() => selectedDecision = val),
                      activeColor: const Color(0xFF2E7D32),
                    ),
                    Expanded(child: Text('BOWL', style: GoogleFonts.outfit(fontWeight: FontWeight.bold))),
                  ],
                ),
              ],
            ),
          ),
          
          const Divider(),
          const SizedBox(height: 12),
          Text('OVERS', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
          const SizedBox(height: 6),
          TextField(
            controller: oversController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '16'),
          ),
          
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showMatchSettingsModal(),
                  icon: const Icon(Icons.settings, size: 18),
                  label: Text('ADVANCED', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    if (selectedTossWinner == null || selectedDecision == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select toss winner and decision!')));
                      return;
                    }
                    
                    setState(() => isUpdating = true);
                    try {
                      await ApiService.updateToss((match['_id'] ?? match['id']).toString(), selectedTossWinner!, selectedDecision!);
                      
                      final totalOvers = int.tryParse(oversController.text) ?? 20;
                      final updatedMatch = Map<String, dynamic>.from(match);
                      updatedMatch['overs_per_match'] = totalOvers;
                      updatedMatch['totalOvers'] = totalOvers;
                      
                      updatedMatch['toss'] = {
                        'winner': selectedTossWinner,
                        'decision': selectedDecision!.toLowerCase(),
                      };
                      
                      final List<dynamic> innings = List.from(updatedMatch['innings'] ?? []);
                      final String opposition = (selectedTossWinner == updatedMatch['teamA']) ? updatedMatch['teamB'] : updatedMatch['teamA'];
                      final String battingTeam = (selectedDecision == 'BAT') ? selectedTossWinner! : opposition;
                      
                      if (innings.isEmpty) {
                        innings.add({
                          'team': battingTeam,
                          'runs': 0, 'wickets': 0, 'overs': 0,
                          'batting': [], 'bowling': [],
                          'extras': {'total': 0, 'wides': 0, 'noBalls': 0, 'byes': 0, 'legByes': 0}
                        });
                        innings.add({
                          'team': (battingTeam == updatedMatch['teamA'] ? updatedMatch['teamB'] : updatedMatch['teamA']),
                          'runs': 0, 'wickets': 0, 'overs': 0,
                          'batting': [], 'bowling': [],
                          'extras': {'total': 0, 'wides': 0, 'noBalls': 0, 'byes': 0, 'legByes': 0}
                        });
                        updatedMatch['innings'] = innings;
                        
                        final currentScore = Map<String, dynamic>.from(updatedMatch['score'] ?? {});
                        currentScore['battingTeam'] = battingTeam;
                        updatedMatch['score'] = currentScore;
                      }
                      
                      setState(() {
                        match = updatedMatch;
                        isUpdating = false;
                      });
                      
                      _showSelectOpeningPlayersModal(battingTeam);
                    } catch (e) {
                      setState(() => isUpdating = false);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to start: $e')));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('START MATCH', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSelectOpeningPlayersModal(String battingTeam) {
    List<String> squadA = List<String>.from(match['squadA'] ?? []);
    List<String> squadB = List<String>.from(match['squadB'] ?? []);
    
    final isTeamA = match['teamA'].toString() == battingTeam;
    final battingSquad = isTeamA ? squadA : squadB;
    final bowlingSquad = isTeamA ? squadB : squadA;
    
    String? striker;
    String? nonStriker;
    String? bowler;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32))),
          padding: EdgeInsets.only(left: 32, right: 32, top: 32, bottom: MediaQuery.of(context).viewInsets.bottom + 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Text('SELECT OPENING PLAYERS', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: const Color(0xFF2E7D32)))),
              const SizedBox(height: 24),
              
              Text('STRIKER', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.5)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: striker,
                decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Select Striker'),
                items: battingSquad.where((e) => e.isNotEmpty).map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                onChanged: (v) => setModalState(() => striker = v),
              ),
              const SizedBox(height: 16),
              
              Text('NON-STRIKER', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.5)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: nonStriker,
                decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Select Non-Striker'),
                items: battingSquad.where((e) => e.isNotEmpty).map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                onChanged: (v) => setModalState(() => nonStriker = v),
              ),
              const SizedBox(height: 16),
              
              Text('OPENING BOWLER', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.5)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: bowler,
                decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Select Bowler'),
                items: bowlingSquad.where((e) => e.isNotEmpty).map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                onChanged: (v) => setModalState(() => bowler = v),
              ),
              
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (striker == null || nonStriker == null || bowler == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select all players!')));
                      return;
                    }
                    if (striker == nonStriker) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Striker and Non-Striker must be different!')));
                      return;
                    }
                    
                    Navigator.pop(context);
                    
                    _handleUpdate('init', value: {
                      's': striker,
                      'ns': nonStriker,
                      'b': bowler,
                      'team': battingTeam
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('START MATCH', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayersTableCard(Map<String, dynamic> score) {
    final String battingTeamName = score['battingTeam']?.toString() ?? '';
    final List<dynamic> innings = match['innings'] as List? ?? [];
    final int battingTeamIdx = innings.indexWhere((inn) => inn['team'] == battingTeamName);
    
    if (battingTeamIdx == -1) return const SizedBox.shrink();
    
    final currentInn = innings[battingTeamIdx];
    final batting = List.from(currentInn['batting'] ?? []);
    
    final striker = score['striker'];
    final nonStriker = score['nonStriker'];
    final bowler = score['bowler'];
    
    final strikerRow = batting.firstWhere((p) => p['player'] == striker, orElse: () => null);
    final nonStrikerRow = batting.firstWhere((p) => p['player'] == nonStriker, orElse: () => null);
    
    final bowlingTeamIdx = battingTeamIdx == 0 ? 1 : 0;
    final bowlingSquad = bowlingTeamIdx < innings.length ? innings[bowlingTeamIdx]['bowling'] as List? ?? [] : [];
    final bowlerRow = bowlingSquad.firstWhere((p) => p['player'] == bowler, orElse: () => null);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(flex: 3, child: Text('BATSMAN', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey))),
              Expanded(child: Center(child: Text('R', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey)))),
              Expanded(child: Center(child: Text('B', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey)))),
              Expanded(child: Center(child: Text('4s', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey)))),
              Expanded(child: Center(child: Text('6s', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey)))),
              Expanded(flex: 2, child: Center(child: Text('SR', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey)))),
            ],
          ),
          const Divider(),
          if (strikerRow != null) _buildBatsmanRow(strikerRow, true),
          if (nonStrikerRow != null) _buildBatsmanRow(nonStrikerRow, false),
          
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(flex: 3, child: Text('BOWLER', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey))),
              Expanded(child: Center(child: Text('O', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey)))),
              Expanded(child: Center(child: Text('M', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey)))),
              Expanded(child: Center(child: Text('R', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey)))),
              Expanded(child: Center(child: Text('W', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey)))),
              Expanded(flex: 2, child: Center(child: Text('ER', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey)))),
            ],
          ),
          const Divider(),
          if (bowlerRow != null) _buildBowlerRow(bowlerRow),
        ],
      ),
    );
  }
  
  Widget _buildBatsmanRow(Map<String, dynamic> row, bool isStriker) {
    final style = GoogleFonts.outfit(
      fontSize: 13,
      fontWeight: isStriker ? FontWeight.w900 : FontWeight.bold,
      color: isStriker ? const Color(0xFF2E7D32) : Colors.black87,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('${row['player']}${isStriker ? '*' : ''}', style: style, maxLines: 1, overflow: TextOverflow.ellipsis)),
          Expanded(child: Center(child: Text('${row['runs'] ?? 0}', style: style))),
          Expanded(child: Center(child: Text('${row['balls'] ?? 0}', style: style))),
          Expanded(child: Center(child: Text('${row['fours'] ?? 0}', style: style))),
          Expanded(child: Center(child: Text('${row['sixes'] ?? 0}', style: style))),
          Expanded(flex: 2, child: Center(child: Text('${row['strikeRate'] ?? 0.0}', style: style))),
        ],
      ),
    );
  }
  
  Widget _buildBowlerRow(Map<String, dynamic> row) {
    final style = GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, color: const Color(0xFF2E7D32));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(row['player']?.toString() ?? '', style: style, maxLines: 1, overflow: TextOverflow.ellipsis)),
          Expanded(child: Center(child: Text('${row['overs'] ?? 0.0}', style: style))),
          Expanded(child: Center(child: Text('${row['maidens'] ?? 0}', style: style))),
          Expanded(child: Center(child: Text('${row['runs'] ?? 0}', style: style))),
          Expanded(child: Center(child: Text('${row['wickets'] ?? 0}', style: style))),
          Expanded(flex: 2, child: Center(child: Text('${row['economy'] ?? 0.0}', style: style))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final score = match['score'] ?? {};
    final bool isPaused = score['isPaused'] ?? false;
    final bool isCompleted = match['status'] == 'completed';
    
    final toss = match['toss'] ?? {};
    final squadA = List.from(match['squadA'] ?? []);
    final squadB = List.from(match['squadB'] ?? []);
    final striker = score['striker'];
    final bowler = score['bowler'];
    
    final bool isMatchSetupReady = squadA.isNotEmpty && squadB.isNotEmpty && toss['winner'] != null && striker != null && bowler != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF2E7D32),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${match['teamA']} vs ${match['teamB']}'.toUpperCase(),
          style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () => _showMatchSettingsModal(),
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
            onPressed: () => PdfService.generateScorecard(match),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            if (isMatchSetupReady) _buildStickyHeader(score),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (isMatchSetupReady) ...[
                    _buildPlayersTableCard(score),
                    const SizedBox(height: 16),
                    _buildTossBanner(),
                    _buildScoringGrid(isPaused, isCompleted),
                  ] else ...[
                    _buildScoringGrid(isPaused, isCompleted),
                  ],
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
    final String battingTeamName = score['battingTeam']?.toString() ?? 'TEAM';
    final int runs = int.tryParse(score['runs']?.toString() ?? '0') ?? 0;
    final double overs = double.tryParse(score['overs']?.toString() ?? '0.0') ?? 0.0;
    final int balls = oversToBalls(overs);
    final double crr = balls > 0 ? (runs / (balls / 6.0)) : 0.0;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 6))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${battingTeamName.toUpperCase()} - 1ST INNINGS',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 14, letterSpacing: 0.5),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)),
                child: Text(
                  'CRR: ${crr.toStringAsFixed(2)}',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${score['runs'] ?? 0}',
                style: GoogleFonts.outfit(fontSize: 72, fontWeight: FontWeight.w900, color: Colors.white),
              ),
              Text(
                ' / ${score['wickets'] ?? 0}',
                style: GoogleFonts.outfit(fontSize: 44, fontWeight: FontWeight.w900, color: Colors.green, ...{ 'color': Colors.green.shade100 }),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '(${score['overs'] ?? 0.0} OVERS)',
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green.shade100),
          ),
          if (score['target'] != null)
             Container(
               margin: const EdgeInsets.only(top: 12),
               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
               decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(100)),
               child: Text('TARGET: ${score['target']}', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: const Color(0xFF1B5E20), fontSize: 13)),
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
          const Icon(Icons.toll, color: Colors.blueAccent, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${toss['winner']} won the toss & elected to ${toss['decision']}'.toUpperCase(),
              style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.blueAccent.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoringGrid(bool isPaused, bool isCompleted) {
    final toss = match['toss'] ?? {};
    final squadA = List.from(match['squadA'] ?? []);
    final squadB = List.from(match['squadB'] ?? []);
    final score = match['score'] ?? {};
    final striker = score['striker'];
    final bowler = score['bowler'];
    
    final bool isReady = squadA.isNotEmpty && squadB.isNotEmpty && toss['winner'] != null && striker != null && bowler != null;
    
    if (!isReady) {
      if (squadA.isEmpty || squadB.isEmpty) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              Text('SQUADS REQUIRED', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange)),
              const SizedBox(height: 12),
              Text('Please enter player squads before continuing setup.', style: GoogleFonts.outfit(color: Colors.grey.shade600)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _showSquadsModal(),
                icon: const Icon(Icons.people),
                label: Text('SETUP SQUADS', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white),
              ),
            ],
          ),
        );
      }
      return _buildScorerSetupCard();
    }
    
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              Wrap(
                spacing: 4,
                runSpacing: 4,
                alignment: WrapAlignment.center,
                children: [
                  _buildCheckbox('Wide', _isWideChecked, (val) {
                    setState(() {
                      _isWideChecked = val ?? false;
                      if (_isWideChecked) _isNbChecked = false;
                    });
                  }),
                  _buildCheckbox('No Ball', _isNbChecked, (val) {
                    setState(() {
                      _isNbChecked = val ?? false;
                      if (_isNbChecked) _isWideChecked = false;
                    });
                  }),
                  _buildCheckbox('Byes', _isByesChecked, (val) {
                    setState(() {
                      _isByesChecked = val ?? false;
                      if (_isByesChecked) _isLbChecked = false;
                    });
                  }),
                  _buildCheckbox('Leg Byes', _isLbChecked, (val) {
                    setState(() {
                      _isLbChecked = val ?? false;
                      if (_isLbChecked) _isByesChecked = false;
                    });
                  }),
                  _buildCheckbox('Wicket', _isWicketChecked, (val) {
                    setState(() {
                      _isWicketChecked = val ?? false;
                    });
                  }),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _showRetireModal(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade100,
                        foregroundColor: Colors.black87,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Retire', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _handleUpdate('swap'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade100,
                        foregroundColor: Colors.black87,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Swap Batsman', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  _actionVerticalButton('Undo', Icons.undo, Colors.orange, _handleUndo),
                  const SizedBox(height: 12),
                  _actionVerticalButton('Partnerships', Icons.people_outline, Colors.teal, _showPartnershipsModal),
                  const SizedBox(height: 12),
                  _actionVerticalButton('Extras', Icons.more_horiz, Colors.indigo, _showExtrasBreakdownModal),
                  const SizedBox(height: 12),
                  _actionVerticalButton(
                    isPaused ? 'Resume' : 'Pause',
                    isPaused ? Icons.play_arrow : Icons.pause,
                    isPaused ? Colors.green : Colors.red,
                    () => _handlePauseToggle(!isPaused),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 3,
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  _circleRunButton('0', 0),
                  _circleRunButton('1', 1),
                  _circleRunButton('2', 2),
                  _circleRunButton('3', 3),
                  _circleRunButton('4', 4),
                  _circleRunButton('5', 5),
                  _circleRunButton('6', 6),
                  InkWell(
                    onTap: _showCustomRunsDialog,
                    borderRadius: BorderRadius.circular(100),
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFF2E7D32), width: 2.5),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                      ),
                      child: Center(
                        child: Text(
                          '...',
                          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF2E7D32)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
  }

  Widget _buildAdvancedCorrectionPanel() {
    return ExpansionTile(
      maintainState: true,
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('ADVANCED CORRECTION PANEL', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: const Color(0xFF1E293B))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: Colors.red.shade600, borderRadius: BorderRadius.circular(4)),
            child: Text('ADVANCED', style: GoogleFonts.outfit(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
          ),
        ],
      ),
      subtitle: Text('Manual state overrides & technical fixes', style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
      children: [
         Container(
           margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
           padding: const EdgeInsets.all(16.0),
           decoration: BoxDecoration(
             color: Colors.white,
             borderRadius: BorderRadius.circular(20),
             border: Border.all(color: Colors.grey.shade200),
             boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
           ),
           child: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
                Text('MANUAL STATE OVERRIDE', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 10, color: Colors.blueAccent, letterSpacing: 1)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildManualInput('Runs', (val) => _handleManualUpdate('runs', val))),
                    const SizedBox(width: 8),
                    Expanded(child: _buildManualInput('Wickets', (val) => _handleManualUpdate('wickets', val))),
                  ],
                ),
                const SizedBox(height: 8),
                _buildManualInput('Overs (e.g. 5.2)', (val) => _handleManualUpdate('overs', val)),
                
                const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider()),
                
                Text('MATCH REDUCTION & TARGET', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 10, color: Colors.indigo, letterSpacing: 1)),
                const SizedBox(height: 12),
                _buildManualInput('Match Total Overs', (val) => _handleReductionUpdate('totalOvers', val)),
                Row(
                  children: [
                    Expanded(child: _buildManualInput('1st Inn Overs', (val) => _handleReductionUpdate('firstInningsOvers', val))),
                    const SizedBox(width: 8),
                    Expanded(child: _buildManualInput('2nd Inn Overs', (val) => _handleReductionUpdate('secondInningsOvers', val))),
                  ],
                ),
                _buildManualInput('Target Points Override', (val) => _handleReductionUpdate('customTarget', val)),
                
                const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider()),
                
                Text('SCHEDULE & TIME CONTROLS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 10, color: Colors.teal, letterSpacing: 1)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.teal.shade50),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16, color: Colors.teal),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'MATCH DATE & TIME',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 12, color: Colors.grey.shade800),
                        ),
                      ),
                      GestureDetector(
                        onTap: _showDateOverridePicker,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(20)),
                          child: Text('ADVANCED CORRECTION', style: GoogleFonts.outfit(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
                        ),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _showDateOverridePicker,
                    icon: const Icon(Icons.edit_calendar_rounded, size: 18),
                    label: Text('UPDATE DATE & TIME FIELDS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.teal.shade800,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.teal.shade100)),
                    ),
                  ),
                ),
                
                const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider()),
                
                Text('CRITICAL ACTIONS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 10, color: Colors.orange.shade900, letterSpacing: 1)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _dangerBtn('FORCE END', () => _handleAdvancedAction('force_end'))),
                    const SizedBox(width: 8),
                    Expanded(child: _dangerBtn('CLEAR LOG', () => _handleAdvancedAction('clear_log'))),
                    const SizedBox(width: 8),
                    Expanded(child: _dangerBtn('PURGE HIST', () => _handleAdvancedAction('purge_history'))),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _actionBtn('DECLARE TIE', Icons.handshake_outlined, _handleDeclareTie)),
                    const SizedBox(width: 8),
                    Expanded(child: _actionBtn('START SUPER OVER', Icons.local_fire_department_outlined, _showSuperOverModal)),
                  ],
                ),
             ],
           ),
         ),
         const SizedBox(height: 16),
      ],
    );
  }

  // Helper methods for buttons to match premium aesthetics
  Widget _controlButton(String label, IconData icon, Color color, VoidCallback? onPressed) {
    return SizedBox(
      width: 80,
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

  bool _checkReadiness() {
    final toss = match['toss'] ?? {};
    final squadA = List.from(match['squadA'] ?? []);
    final squadB = List.from(match['squadB'] ?? []);
    final score = match['score'] ?? {};
    final striker = score['striker'];
    final bowler = score['bowler'];

    if (squadA.isEmpty || squadB.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select squads before starting the match.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red));
      return false;
    }
    if (toss['winner'] == null || toss['decision'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Complete toss before scoring.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red));
      return false;
    }
    if (striker == null || bowler == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select striker and bowler.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red));
      return false;
    }
    return true;
  }

  Widget _scoreBtn(String label, VoidCallback onPressed, {bool isWicket = false}) {
    final color = isWicket ? Colors.red : Colors.blue;
    return SizedBox(
      width: isWicket ? 80 : 60,
      child: ElevatedButton(
        onPressed: (isUpdating || (match['score']?['isPaused'] ?? false)) 
          ? null 
          : () {
            if (_checkReadiness()) {
              onPressed();
            }
          },
        style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: color,
            elevation: 2,
            shadowColor: color.withOpacity(0.2),
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 0),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: color.withOpacity(0.5)))),
        child: Text(label, style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16)),
      ),
    );
  }


  Widget _extraBtn(String label, VoidCallback onPressed) {
    return SizedBox(
      width: 90,
      child: ElevatedButton(
        onPressed: (isUpdating || (match['score']?['isPaused'] ?? false)) 
          ? null 
          : () {
            if (_checkReadiness()) {
              onPressed();
            }
          },
        style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber.shade50,
            foregroundColor: Colors.amber.shade900,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.amber.shade200))),
        child: Text(label, style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 8), textAlign: TextAlign.center),
      ),
    );
  }


  Widget _actionBtn(String label, IconData icon, VoidCallback onPressed) {
    return SizedBox(
      width: 140,
      child: ElevatedButton.icon(
        onPressed: (isUpdating || (match['score']?['isPaused'] ?? false)) 
          ? null 
          : () {
            if (_checkReadiness()) {
              onPressed();
            }
          },
        icon: Icon(icon, size: 14),
        label: Text(label, style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 8)),
        style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF1F5F9),
            foregroundColor: const Color(0xFF475569),
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
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
    final legalBalls = thisOver.where((b) {
      final s = b.toString().toUpperCase();
      return !s.contains('WD') && !s.contains('W+') && !s.contains('NB');
    }).length;
    final remaining = 6 - legalBalls;

    if (remaining > 0 && thisOver.isNotEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(
         content: Text('🩹 Bowler replaced due to injury. $remaining balls remaining.'),
         backgroundColor: Colors.orange,
         duration: const Duration(seconds: 4),
       ));
    }
    final String battingTeamName = match['score']?['battingTeam']?.toString() ?? '';
    final int bowlingTeamIdx = (match['teamA'].toString() == battingTeamName) ? 1 : 0;
    final bowlingSquad = List<String>.from((bowlingTeamIdx == 0 ? match['teamASquad'] : match['teamBSquad']) ?? []);
    
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
    final oversController = TextEditingController(text: (match['overs_per_match'] ?? match['totalOvers'] ?? '').toString());

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
                        updatedMatch['overs_per_match'] = int.tryParse(oversController.text) ?? (updatedMatch['overs_per_match'] ?? updatedMatch['totalOvers']);
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))));
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

  void _handleReductionUpdate(String field, String value) {
      if (value.isEmpty) return;
      final updatedMatch = Map<String, dynamic>.from(match);
      final currentScore = Map<String, dynamic>.from(updatedMatch['score'] ?? {});
      
      final numValue = num.tryParse(value);
      if (numValue == null) return;

      updatedMatch['firstInningsOvers'] ??= updatedMatch['overs_per_match'] ?? updatedMatch['totalOvers'];
      updatedMatch['secondInningsOvers'] ??= updatedMatch['overs_per_match'] ?? updatedMatch['totalOvers'];

      bool shouldRecalcTarget = false;
      if (field == 'totalOvers') {
          updatedMatch['totalOvers'] = numValue.toInt();
          updatedMatch['overs_per_match'] = numValue.toInt();
          updatedMatch['firstInningsOvers'] = numValue;
          updatedMatch['secondInningsOvers'] = numValue;
          shouldRecalcTarget = true;
      } else if (field == 'firstInningsOvers') {
          updatedMatch['firstInningsOvers'] = numValue;
          shouldRecalcTarget = true;
      } else if (field == 'secondInningsOvers') {
          updatedMatch['secondInningsOvers'] = numValue;
          shouldRecalcTarget = true;
      } else if (field == 'customTarget') {
          currentScore['target'] = numValue.toInt();
      }

      if (shouldRecalcTarget && (updatedMatch['innings'] as List?)?.isNotEmpty == true) {
          final firstInn = updatedMatch['innings'][0];
          if (currentScore['target'] != null || ((firstInn['runs'] ?? 0) > 0 && (firstInn['overs'] ?? 0) > 0)) {
              final t1Score = firstInn['runs'] ?? 0;
              final t1OversPlayed = (firstInn['overs'] as num?) ?? updatedMatch['firstInningsOvers'];
              final t1OversSafe = t1OversPlayed > 0 ? t1OversPlayed : 1;
              final newT2Overs = updatedMatch['secondInningsOvers'];
              
              if (newT2Overs < t1OversSafe) {
                  currentScore['target'] = ((t1Score / t1OversSafe) * newT2Overs).floor() + 1;
              } else {
                  currentScore['target'] = t1Score + 1;
              }
          }
      }

      updatedMatch['score'] = currentScore;
      _handleUpdate('manual', value: updatedMatch);
  }

  Future<void> _showDateOverridePicker() async {
      final matchDateStr = match['date']?.toString();
      final initDate = (matchDateStr != null && matchDateStr.isNotEmpty) ? DateTime.tryParse(matchDateStr)?.toLocal() ?? DateTime.now() : DateTime.now();

      final pickedDate = await showDatePicker(
          context: context,
          initialDate: initDate,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
      );
      if (pickedDate == null) return;

      final pickedTime = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(initDate),
          helpText: 'SELECT START TIME (24H: ${pickedDate.year}-${pickedDate.month.toString().padLeft(2,'0')}-${pickedDate.day.toString().padLeft(2,'0')})',
      );
      if (pickedTime == null) return;

      final newDateTime = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);

      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('CONFIRM DATE OVERRIDE', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.teal.shade900)),
          content: Text('Update match start to: \n${DateFormat('MMM d, y').format(newDateTime)} at ${pickedTime.format(context)}?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('PROCEED', style: TextStyle(color: Colors.teal))),
          ],
        ),
      );

      if (confirm != true) return;

      setState(() => isUpdating = true);
      try {
          final updated = await ApiService.updateMatchDateTime((match['_id'] ?? match['id']).toString(), {'matchDateTime': newDateTime.toIso8601String()});
          setState(() { match = updated; isUpdating = false; });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Schedule Updated Successfully!')));
      } catch (e) {
          setState(() => isUpdating = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))));
      }
  }

  Future<void> _handleAdvancedAction(String action) async {
      // Implement Force End, Clear Log, Purge Hist logic
      String confirmMsg = '';
      Map<String, dynamic> payload = {};
      final currentScore = Map<String, dynamic>.from(match['score'] ?? {});

      if (action == 'force_end') {
          confirmMsg = 'Force end this innings?';
          currentScore['overs'] = (match['overs_per_match'] ?? match['totalOvers'] ?? 20).toString();
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
                  _handleUpdate('extra', value: type, params: {'amount': extraRuns, 'isBat': isBat});
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

  Future<void> _handleDeclareTie() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('DECLARE TIE?', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
        content: const Text('Are you sure you want to end this match as a tie?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('DECLARE TIE', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      final updatedMatch = Map<String, dynamic>.from(match);
      updatedMatch['status'] = 'completed';
      _handleUpdate('manual', value: updatedMatch);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Match ended as a Tie! 🤝')));
    }
  }

  void _showSuperOverModal() {
    String selectedTeam = match['teamA'];
    
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
              Text('START SUPER OVER', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.orange.shade900)),
              const SizedBox(height: 20),
              Text('Who bats first in Super Over?', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: Text(match['teamA'], style: GoogleFonts.outfit(fontSize: 12)),
                      value: match['teamA'],
                      groupValue: selectedTeam,
                      onChanged: (v) => setModalState(() => selectedTeam = v!),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: Text(match['teamB'], style: GoogleFonts.outfit(fontSize: 12)),
                      value: match['teamB'],
                      groupValue: selectedTeam,
                      onChanged: (v) => setModalState(() => selectedTeam = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _handleStartSuperOver(selectedTeam);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade800,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text('FIRE UP SUPER OVER 🔥', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleStartSuperOver(String nextBattingTeam) async {
    final updatedMatch = Map<String, dynamic>.from(match);
    final String nextBowlingTeam = (nextBattingTeam == updatedMatch['teamA'] ? updatedMatch['teamB'] : updatedMatch['teamA']);

    final innings = List<Map<String, dynamic>>.from((updatedMatch['innings'] as List).map((e) => Map<String, dynamic>.from(e)));

    // Push BOTH innings for the Super Over pair (Web logic parity)
    innings.add({
      'team': nextBattingTeam, 'runs': 0, 'wickets': 0, 'overs': 0,
      'batting': [], 'bowling': [],
      'extras': {'total': 0, 'wides': 0, 'noBalls': 0, 'byes': 0, 'legByes': 0}
    });
    innings.add({
      'team': nextBowlingTeam, 'runs': 0, 'wickets': 0, 'overs': 0,
      'batting': [], 'bowling': [],
      'extras': {'total': 0, 'wides': 0, 'noBalls': 0, 'byes': 0, 'legByes': 0}
    });

    updatedMatch['innings'] = innings;
    updatedMatch['score'] = {
      'battingTeam': nextBattingTeam,
      'runs': 0, 'wickets': 0, 'overs': 0,
      'thisOver': [],
      'target': null
    };
    updatedMatch['status'] = 'live';
    updatedMatch['currentBatsmen'] = [];
    updatedMatch['currentBowler'] = null;

    _handleUpdate('manual', value: updatedMatch);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Super Over Started! $nextBattingTeam batting first.')));
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

  void _showTossModal() {
    final squadA = List.from(match['squadA'] ?? []);
    final squadB = List.from(match['squadB'] ?? []);
    if (squadA.isEmpty || squadB.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select squads first!', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red));
      return;
    }

    final toss = match['toss'] ?? {};
    if (toss['winner'] != null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Toss already conducted!')));
      return;
    }

    String? selectedWinner;
    String? selectedDecision;

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
              Text('CONDUCT TOSS', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.purple)),
              const SizedBox(height: 24),
              Text('Who won the toss?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: Text(match['teamA'], style: GoogleFonts.outfit(fontSize: 12)),
                      value: match['teamA'],
                      groupValue: selectedWinner,
                      onChanged: (v) => setModalState(() => selectedWinner = v),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: Text(match['teamB'], style: GoogleFonts.outfit(fontSize: 12)),
                      value: match['teamB'],
                      groupValue: selectedWinner,
                      onChanged: (v) => setModalState(() => selectedWinner = v),
                    ),
                  ),
                ],
              ),
              if (selectedWinner != null) ...[
                const SizedBox(height: 16),
                Text('Decision?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        title: Text('Bat', style: GoogleFonts.outfit(fontSize: 12)),
                        value: 'bat',
                        groupValue: selectedDecision,
                        onChanged: (v) => setModalState(() => selectedDecision = v),
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: Text('Bowl', style: GoogleFonts.outfit(fontSize: 12)),
                        value: 'bowl',
                        groupValue: selectedDecision,
                        onChanged: (v) => setModalState(() => selectedDecision = v),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: (selectedWinner == null || selectedDecision == null) ? null : () {
                  Navigator.pop(context);
                  _handleTossUpdate(selectedWinner == match['teamA'] ? 'teamA' : 'teamB', selectedDecision!);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text('CONFIRM TOSS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
              )
            ],
          ),
        ),
      ),
    );
  }

  void _showSquadsModal() {
    final teamA = match['teamA'];
    final teamB = match['teamB'];
    List<String> squadA = List<String>.from(match['squadA'] ?? []);
    List<String> squadB = List<String>.from(match['squadB'] ?? []);
    while(squadA.length < 11) squadA.add('');
    while(squadB.length < 11) squadB.add('');

    String? striker = match['score']?['striker'];
    String? nonStriker = match['score']?['nonStriker'];
    String? bowler = match['score']?['bowler'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32))),
          padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('MANAGE SQUADS & SETUP', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.blueAccent)),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(teamA.toUpperCase(), style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      for (int i=0; i<squadA.length; i++) Padding(
                         padding: const EdgeInsets.only(bottom: 8),
                         child: TextFormField(
                            initialValue: squadA[i],
                            onChanged: (v) => squadA[i] = v,
                            decoration: InputDecoration(hintText: 'Player ${i+1}', isDense: true, border: const OutlineInputBorder()),
                         ),
                      ),
                      TextButton.icon(
                         onPressed: () => setModalState(() => squadA.add('')),
                         icon: const Icon(Icons.add, size: 20),
                         label: const Text('Add More Players'),
                      ),
                      const SizedBox(height: 16),
                      Text(teamB.toUpperCase(), style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      for (int i=0; i<squadB.length; i++) Padding(
                         padding: const EdgeInsets.only(bottom: 8),
                         child: TextFormField(
                            initialValue: squadB[i],
                            onChanged: (v) => squadB[i] = v,
                            decoration: InputDecoration(hintText: 'Player ${i+1}', isDense: true, border: const OutlineInputBorder()),
                         ),
                      ),
                      TextButton.icon(
                         onPressed: () => setModalState(() => squadB.add('')),
                         icon: const Icon(Icons.add, size: 20),
                         label: const Text('Add More Players'),
                      ),
                      const SizedBox(height: 24),
                      Text('STARTING PLAYERS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.indigo)),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                         decoration: const InputDecoration(labelText: 'Striker', border: OutlineInputBorder()),
                         value: striker != null && [...squadA, ...squadB].contains(striker) ? striker : null,
                         items: [...squadA, ...squadB].where((e) => e.isNotEmpty).toSet().map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                         onChanged: (v) => setModalState(() => striker = v),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                         decoration: const InputDecoration(labelText: 'Non-Striker', border: OutlineInputBorder()),
                         value: nonStriker != null && [...squadA, ...squadB].contains(nonStriker) ? nonStriker : null,
                         items: [...squadA, ...squadB].where((e) => e.isNotEmpty).toSet().map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                         onChanged: (v) => setModalState(() => nonStriker = v),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                         decoration: const InputDecoration(labelText: 'Bowler', border: OutlineInputBorder()),
                         value: bowler != null && [...squadA, ...squadB].contains(bowler) ? bowler : null,
                         items: [...squadA, ...squadB].where((e) => e.isNotEmpty).toSet().map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                         onChanged: (v) => setModalState(() => bowler = v),
                      ),
                    ]
                  ),
                )
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                   onPressed: () {
                     // Save to API
                     final sA = squadA.where((e) => e.trim().isNotEmpty).toList();
                     final sB = squadB.where((e) => e.trim().isNotEmpty).toList();
                     if (sA.length < 11 || sB.length < 11) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter at least 11 players for each team')));
                        return;
                     }
                     Navigator.pop(context);
                     
                     final updated = Map<String, dynamic>.from(match);
                     updated['squadA'] = sA;
                     updated['squadB'] = sB;
                     
                     final score = Map<String, dynamic>.from(updated['score'] ?? {});
                     if (striker != null) score['striker'] = striker;
                     if (nonStriker != null) score['nonStriker'] = nonStriker;
                     if (bowler != null) score['bowler'] = bowler;
                     updated['score'] = score;
                     
                     _handleUpdate('manual', value: updated);
                   },
                   style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                   ),
                   child: Text('SAVE SQUADS & SETUP', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16)),
                )
              )
            ],
          ),
        ),
      ),
    );
  }

  void _showRetireModal() {
    final score = match['score'] ?? {};
    final striker = score['striker'];

    if (striker == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('RETIRE BATTER?', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
        content: Text('Are you sure you want to retire $striker?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _handleUpdate('retire', value: striker);
            },
            child: const Text('RETIRE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
