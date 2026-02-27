import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import 'squad_screen.dart';
import '../widgets/app_footer.dart';
import 'package:intl/intl.dart';

class AdminLiveMatchScreen extends StatefulWidget {
  final Map<String, dynamic> matchData;
  AdminLiveMatchScreen({required this.matchData});

  @override
  _AdminLiveMatchScreenState createState() => _AdminLiveMatchScreenState();
}

class _AdminLiveMatchScreenState extends State<AdminLiveMatchScreen> {
  late Map<String, dynamic> match;
  bool isLoading = false;
  bool isSaving = false;

  final Color primaryColor = Color(0xFF2563EB); // Premium Blue
  final Color accentColor = Color(0xFF1D4ED8); // Darker Blue
  final Color successColor = Color(0xFF059669); // Emerald Green
  final Color warningColor = Color(0xFFD97706); // Amber
  final Color dangerColor = Color(0xFFDC2626); // Red

  bool _showBlast = false;
  int _lastBoundary = 0;

  @override
  void initState() {
    super.initState();
    match = widget.matchData;
  }

  bool _needsSave = false;

  // Manual save for correction panel edits
  void _saveLocalMatch() async {
    _saveMatch();
  }

  Future<void> _saveMatch() async {
    if (isSaving) {
       _needsSave = true;
       return;
    }

    setState(() => isSaving = true);
    _needsSave = false;
    
    try {
      var matchToSend = Map<String, dynamic>.from(match);
      matchToSend.remove('history'); // DO NOT send history to server to prevent payload bloat
      
      await ApiService.updateMatch((match['_id'] ?? match['id']).toString(), matchToSend);
      // Success - no snackbar needed for every auto-save to avoid spam
    } catch (e) {
      _showSnackBar(e.toString().replaceAll('Exception: ', ''), isError: true);
    } finally {
      setState(() => isSaving = false);
      if (_needsSave) {
         _saveMatch();
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: isError ? Colors.red.shade800 : Colors.green.shade800,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(20),
        duration: Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      )
    );
  }

  Future<void> _handleUpdate(String type, dynamic value, [Map<String, dynamic>? params]) async {
    // --- Prevent Editing if Match Completed (EXCEPT STATUS OVERRIDE) ---
    /* if (match['status'] == 'completed' && type != 'status_override') {
       _showSnackBar('Match is completed! No further edits allowed.', isError: true);
       return;
    } */
    // ------------------------------------------

    // --- History Tracking for Undo (Delete Previous Ball) ---
    if (['runs', 'extra', 'wicket', 'swap_strike'].contains(type)) {
       try {
         List<dynamic> history = (match['history'] as List<dynamic>?)?.toList() ?? [];
         var snapshot = jsonDecode(jsonEncode(match));
         if (snapshot is Map) snapshot.remove('history');
         history.add(snapshot);
         // Limit history to 10 items to prevent bloat (reduced from 20 for safety)
         if (history.length > 10) history.removeAt(0);
         match['history'] = history;
       } catch (e) {
         print("History Error: $e");
       }
    }
    
    // setState(() => isSaving = true); // Removed to prevent deadlock with _saveMatch checking isSaving
    var updatedMatch = Map<String, dynamic>.from(match);
    
    // Ensure score and innings structure exists
    if (updatedMatch['score'] == null) {
      updatedMatch['score'] = {
        'battingTeam': updatedMatch['teamA'],
        'runs': 0, 
        'wickets': 0, 
        'overs': 0,
        'thisOver': []
      };
    }

    if (updatedMatch['innings'] == null || (updatedMatch['innings'] as List).isEmpty) {
       updatedMatch['innings'] = [
         {'team': updatedMatch['teamA'], 'runs': 0, 'wickets': 0, 'overs': 0, 'batting': [], 'bowling': [], 'extras': {'total': 0, 'wides': 0, 'noBalls': 0, 'byes': 0, 'legByes': 0}},
         {'team': updatedMatch['teamB'], 'runs': 0, 'wickets': 0, 'overs': 0, 'batting': [], 'bowling': [], 'extras': {'total': 0, 'wides': 0, 'noBalls': 0, 'byes': 0, 'legByes': 0}}
       ];
    }
    
    List<dynamic> inningsList = updatedMatch['innings'];
    String battingTeamName = updatedMatch['score']['battingTeam'] ?? updatedMatch['teamA'];
    // Use lastIndexWhere to support multiple innings (Super Over)
    int battingIdx = inningsList.lastIndexWhere((inn) => inn['team'] == battingTeamName);
    if (battingIdx == -1) battingIdx = 0; 
    
    // Find opposing team's last innings for bowling stats
    int bowlingIdx = inningsList.lastIndexWhere((inn) => inn['team'] != battingTeamName);
    if (bowlingIdx == -1) bowlingIdx = battingIdx == 0 ? 1 : 0;
    
    var currentInnings = inningsList[battingIdx];
    var currentBowling = inningsList[bowlingIdx];

    List squadA = updatedMatch['teamASquad'] ?? [];
    List squadB = updatedMatch['teamBSquad'] ?? [];
    List battingSquad = battingTeamName == updatedMatch['teamA'] ? squadA : squadB;
    List bowlingSquad = battingTeamName == updatedMatch['teamA'] ? squadB : squadA;

    // Helper to find player index
    int findBatIndex(String name) => (currentInnings['batting'] as List).indexWhere((p) => p['player'] == name);
    int findBowlIndex(String name) => (currentBowling['bowling'] as List).indexWhere((p) => p['player'] == name);

    if (type == 'init') {
      // Start Match logic
      String s = value['s']; String ns = value['ns']; String b = value['b'];
      
      if (s == ns) {
        _showSnackBar('Striker and Non-Striker must be different!', isError: true);
        return;
      }

      // Validation moved after auto-detection


      // Auto-detect batting team from striker's squad
      String derivedBattingTeam = updatedMatch['teamA'];
      if ((squadB as List).contains(s)) derivedBattingTeam = updatedMatch['teamB'];
      
      // Update batting team immediately so innings logic aligns
      updatedMatch['score']['battingTeam'] = derivedBattingTeam;
      
      // Re-fetch current innings based on correct batting team
      battingTeamName = derivedBattingTeam;
      battingIdx = inningsList.lastIndexWhere((inn) => inn['team'] == battingTeamName);
      if (battingIdx == -1) battingIdx = (squadA as List).contains(s) ? 0 : 1;
      
      currentInnings = inningsList[battingIdx];
      // Recalculate bowling innings too
      bowlingIdx = inningsList.lastIndexWhere((inn) => inn['team'] != battingTeamName);
      if (bowlingIdx == -1) bowlingIdx = battingIdx == 0 ? 1 : 0;
      currentBowling = inningsList[bowlingIdx];

      // Re-validate based on new batting team
      List newBattingSquad = derivedBattingTeam == updatedMatch['teamA'] ? squadA : squadB;
      List newBowlingSquad = derivedBattingTeam == updatedMatch['teamA'] ? squadB : squadA;
      
      /* 
      // Validation relaxed for mobile to prevent blocking
      if (!newBattingSquad.contains(s) || !newBattingSquad.contains(ns)) {
         _showSnackBar('Player not found in ${derivedBattingTeam} squad!', isError: true);
         return;
      }
      if (!newBowlingSquad.contains(b)) {
         _showSnackBar('Bowler not found in opponent squad!', isError: true);
         return;
      } 
      */

      if (findBatIndex(s) == -1) (currentInnings['batting'] as List).add({'player': s, 'status': 'not out', 'runs': 0, 'balls': 0, 'fours': 0, 'sixes': 0, 'strikeRate': 0});
      if (findBatIndex(ns) == -1) (currentInnings['batting'] as List).add({'player': ns, 'status': 'not out', 'runs': 0, 'balls': 0, 'fours': 0, 'sixes': 0, 'strikeRate': 0});
      if (findBowlIndex(b) == -1) (currentBowling['bowling'] as List).add({'player': b, 'overs': 0, 'maidens': 0, 'runs': 0, 'wickets': 0, 'economy': 0});
      
      updatedMatch['currentBatsmen'] = [
        {'name': s, 'onStrike': true, 'runs': 0, 'balls': 0},
        {'name': ns, 'onStrike': false, 'runs': 0, 'balls': 0}
      ];
      updatedMatch['currentBowler'] = b;
      updatedMatch['status'] = 'live';
    } 
    else if (type == 'runs' || type == 'extra' || type == 'wicket' || type == 'retire') {
      List<dynamic> curBatsmen = updatedMatch['currentBatsmen'] ?? [];
      
      if (curBatsmen.length < 2) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Batsmen data missing. Check Squads.')));
         return; 
      }

      String striker = curBatsmen.firstWhere((b) => b['onStrike'] == true, orElse: () => curBatsmen[0])['name'];
      String nonStriker = curBatsmen.firstWhere((b) => b['onStrike'] == false, orElse: () => curBatsmen[1])['name'];
      String bowler = updatedMatch['currentBowler'] ?? '';

      int sIdx = findBatIndex(striker);
      int bIdx = findBowlIndex(bowler);

      if (sIdx == -1 && striker.isNotEmpty) {
          (currentInnings['batting'] as List).add({'player': striker, 'status': 'not out', 'runs': 0, 'balls': 0, 'fours': 0, 'sixes': 0, 'strikeRate': 0});
          sIdx = (currentInnings['batting'] as List).length - 1;
      }
      if (bIdx == -1 && bowler.isNotEmpty) {
          (currentBowling['bowling'] as List).add({'player': bowler, 'overs': 0, 'maidens': 0, 'runs': 0, 'wickets': 0, 'economy': 0});
          bIdx = (currentBowling['bowling'] as List).length - 1;
      }

      bool ballCounts = true;

      if (type == 'runs') {
        int runs = value;
        // Validation: Prevent runs if overs finished
        if ((currentInnings['overs'] as num) >= (match['totalOvers'] as int)) {
             _showSnackBar('Overs limit reached! Cannot add runs.', isError: true);
             return;
        }

        currentInnings['batting'][sIdx]['runs'] += runs;
        currentInnings['batting'][sIdx]['balls'] += 1;
        if (runs == 4) currentInnings['batting'][sIdx]['fours'] += 1;
        if (runs == 6) currentInnings['batting'][sIdx]['sixes'] += 1;
        
        currentBowling['bowling'][bIdx]['runs'] += runs;
        currentInnings['runs'] += runs;
        
        // Team level run breakdown
        if (runs == 0) currentInnings['dots'] = (currentInnings['dots'] ?? 0) + 1;
        else if (runs == 1) currentInnings['ones'] = (currentInnings['ones'] ?? 0) + 1;
        else if (runs == 2) currentInnings['twos'] = (currentInnings['twos'] ?? 0) + 1;
        else if (runs == 3) currentInnings['threes'] = (currentInnings['threes'] ?? 0) + 1;
        else if (runs == 4) currentInnings['fours'] = (currentInnings['fours'] ?? 0) + 1;
        else if (runs == 6) currentInnings['sixes'] = (currentInnings['sixes'] ?? 0) + 1;

        if (runs == 4 || runs == 6) {
            setState(() {
              _showBlast = true;
              _lastBoundary = runs;
            });
            Future.delayed(Duration(seconds: 2), () {
              if (mounted) setState(() => _showBlast = false);
            });
         }
         
         if (runs % 2 != 0) {
           var t = curBatsmen[0]['onStrike'];
           curBatsmen[0]['onStrike'] = curBatsmen[1]['onStrike'];
           curBatsmen[1]['onStrike'] = t;
        }

        // Track this over
        if (updatedMatch['score']['thisOver'] == null) updatedMatch['score']['thisOver'] = [];
        (updatedMatch['score']['thisOver'] as List).add(runs.toString());
      } else if (type == 'extra') {
         int amount = params?['amount'] ?? 1;
         currentInnings['runs'] += amount;
         currentInnings['extras']['total'] += amount;
         
         String extraLabel = value.toString().toUpperCase();
         if (value == 'w') { 
            currentInnings['extras']['wides'] += amount; 
            ballCounts = false; 
            currentBowling['bowling'][bIdx]['runs'] += amount;
            currentBowling['bowling'][bIdx]['wides'] = (currentBowling['bowling'][bIdx]['wides'] ?? 0) + amount;
            extraLabel = '${amount}wd';
         }
         else if (value == 'nb') { 
            currentInnings['extras']['noBalls'] += amount; 
            ballCounts = false; 
            currentBowling['bowling'][bIdx]['runs'] += amount; 
            currentBowling['bowling'][bIdx]['noBalls'] = (currentBowling['bowling'][bIdx]['noBalls'] ?? 0) + amount;
            extraLabel = '${amount}nb';
         }
         else if (value == 'b') { 
            currentInnings['extras']['byes'] = (currentInnings['extras']['byes'] ?? 0) + amount; 
            extraLabel = '${amount}b';
         }
         else if (value == 'lb') { 
            currentInnings['extras']['legByes'] = (currentInnings['extras']['legByes'] ?? 0) + amount; 
            extraLabel = '${amount}lb';
         }

         if (updatedMatch['score']['thisOver'] == null) updatedMatch['score']['thisOver'] = [];
         (updatedMatch['score']['thisOver'] as List).add(extraLabel);
      } else if (type == 'wicket') {
         currentInnings['wickets'] += 1;
         var wDetail = params; 
         String outStatus = 'out';
         String outPlayerName = wDetail?['whoOut'] ?? striker;
         bool crossed = wDetail?['crossed'] ?? false;
         int completedRuns = wDetail?['runs'] ?? 0;
         String ballType = wDetail?['ballStatus'] ?? 'normal'; // normal, wide, nb, mankad

         if (completedRuns > 0) {
            currentInnings['runs'] += completedRuns;
            currentInnings['batting'][sIdx]['runs'] += completedRuns;
            currentBowling['bowling'][bIdx]['runs'] += completedRuns;
         }
         
         if (ballType == 'wide') {
            currentInnings['runs'] += 1;
            currentInnings['extras']['wides'] = (currentInnings['extras']['wides'] ?? 0) + 1;
            currentInnings['extras']['total'] = (currentInnings['extras']['total'] ?? 0) + 1;
            currentBowling['bowling'][bIdx]['runs'] += 1;
            ballCounts = false;
         } else if (ballType == 'no-ball') {
            currentInnings['runs'] += 1;
            currentInnings['extras']['noBalls'] = (currentInnings['extras']['noBalls'] ?? 0) + 1;
            currentInnings['extras']['total'] = (currentInnings['extras']['total'] ?? 0) + 1;
            currentBowling['bowling'][bIdx]['runs'] += 1;
            ballCounts = false;
         } else if (ballType == 'mankad') {
            ballCounts = false;
         }

         if (wDetail != null) {
            String t = wDetail['type'];
            String f = wDetail['fielder'] ?? '';
            if (t == 'bowled') outStatus = 'b $bowler';
            else if (t == 'caught') outStatus = 'c $f b $bowler';
            else if (t == 'lbw') outStatus = 'lbw b $bowler';
            else if (t == 'run out') outStatus = 'run out ($f)';
            else if (t == 'stumped') outStatus = 'st $f b $bowler';
            else if (t == 'hit wicket') outStatus = 'hit wicket b $bowler';
         }
         
         int targetIdx = findBatIndex(outPlayerName);
         if (targetIdx == -1) targetIdx = sIdx;

         currentInnings['batting'][targetIdx]['status'] = outStatus;
         if (wDetail?['type'] != 'run out') currentBowling['bowling'][bIdx]['wickets'] += 1;
         
         if (ballType != 'mankad' && (ballType == 'normal' || wDetail?['type'] != 'stumped')) {
            // Regular wickets count as balls unless wide/nb/mankad
            // Stumped on a wide is already handled by ballCounts=false
            if (ballCounts) currentInnings['batting'][sIdx]['balls'] += 1;
         }

         // Update currentBatsmen: mark out player slot as empty
         List<dynamic> cb = List<dynamic>.from(updatedMatch['currentBatsmen'] ?? []);
         for (int i = 0; i < cb.length; i++) {
            if (cb[i]['name'] == outPlayerName) {
               cb[i]['name'] = ''; 
            } else if (crossed && ballType != 'mankad') {
               cb[i]['onStrike'] = !cb[i]['onStrike'];
            }
         }
         updatedMatch['currentBatsmen'] = cb;

         if (updatedMatch['score']['thisOver'] == null) updatedMatch['score']['thisOver'] = [];
         (updatedMatch['score']['thisOver'] as List).add('W');

          // Track Fall of Wicket
          if (currentInnings['fallOfWickets'] == null) currentInnings['fallOfWickets'] = [];
          (currentInnings['fallOfWickets'] as List).add({
            'wicket': currentInnings['wickets'],
            'runs': currentInnings['runs'],
            'overs': currentInnings['overs'],
            'player': outPlayerName
          });
      } else if (type == 'retire') {
         currentInnings['batting'][sIdx]['status'] = 'retired hurt';
      }

      if (ballCounts) {
         double overs = (currentInnings['overs'] as num).toDouble();
         int balls = ((overs.floor() * 6) + ((overs * 10) % 10).round()).toInt() + 1;
         if (balls % 6 == 0) {
             currentInnings['overs'] = (balls / 6).toDouble();
             updatedMatch['score']['lastOverBowler'] = bowler; // Track for Law 17.8
             var t = curBatsmen[0]['onStrike'];
             curBatsmen[0]['onStrike'] = curBatsmen[1]['onStrike'];
             curBatsmen[1]['onStrike'] = t;
             updatedMatch['score']['thisOver'] = []; // Clear over history
             if (currentInnings['overs'] < updatedMatch['totalOvers']) {
                Future.delayed(Duration(milliseconds: 500), () => _showNewBowlerDialog());
             }
         } else {
             currentInnings['overs'] = (balls ~/ 6) + (balls % 6) / 10;
         }
         
         double bOvers = (currentBowling['bowling'][bIdx]['overs'] as num).toDouble();
         int bBalls = ((bOvers.floor() * 6) + ((bOvers * 10) % 10).round()).toInt() + 1;
         if (bBalls % 6 == 0) currentBowling['bowling'][bIdx]['overs'] = (bBalls / 6).toDouble();
         else currentBowling['bowling'][bIdx]['overs'] = (bBalls ~/ 6) + (bBalls % 6) / 10;
      }

      // Calculate Stats (SR & Eco)
      (currentInnings['batting'] as List).forEach((p) {
          if (p['balls'] > 0) p['strikeRate'] = double.parse(((p['runs'] / p['balls']) * 100).toStringAsFixed(2));
      });
      (currentBowling['bowling'] as List).forEach((p) {
          double ov = (p['overs'] as num).toDouble();
          int totB = (ov.floor() * 6) + ((ov * 10) % 10).round().toInt();
          if (totB > 0) p['economy'] = double.parse(((p['runs'] / totB) * 6).toStringAsFixed(2));
      });

      for (var b in (updatedMatch['currentBatsmen'] as List)) {
         var p = (currentInnings['batting'] as List).firstWhere((pl) => pl['player'] == b['name'], orElse: () => null);
         if (p != null) { b['runs'] = p['runs']; b['balls'] = p['balls']; }
      }

      // Sync score to main score object BEFORE completion logic
      updatedMatch['score']['runs'] = currentInnings['runs'];
      updatedMatch['score']['wickets'] = currentInnings['wickets'];
      updatedMatch['score']['overs'] = currentInnings['overs'];

      // Completion Logic
      bool isSuperOver = inningsList.length > 2;
      bool isAllOut = currentInnings['wickets'] >= (isSuperOver ? 2 : 10);
      bool isOversCompleted = currentInnings['overs'] >= (isSuperOver ? 1 : updatedMatch['totalOvers']);
      bool targetChased = updatedMatch['score']['target'] != null && currentInnings['runs'] >= updatedMatch['score']['target'];

      if (isAllOut || isOversCompleted || targetChased) {
          if (updatedMatch['score']['target'] == null) {
              updatedMatch['score']['target'] = (currentInnings['runs'] as int) + 1;
              String nextBatTeam = updatedMatch['score']['battingTeam'] == updatedMatch['teamA'] ? updatedMatch['teamB'] : updatedMatch['teamA'];
              
              _showSnackBar('Innings Over! Target: ${updatedMatch['score']['target']}');
              
              // Push new innings if SO first half ended
              if (isSuperOver && inningsList.length % 2 != 0) {
                 inningsList.add({
                   'team': nextBatTeam, 'runs': 0, 'wickets': 0, 'overs': 0, 'batting': [], 'bowling': [], 
                   'extras': {'total': 0, 'wides': 0, 'noBalls': 0, 'byes': 0, 'legByes': 0}
                 });
              }

              updatedMatch['score']['battingTeam'] = nextBatTeam;
              updatedMatch['score']['runs'] = 0; updatedMatch['score']['wickets'] = 0; updatedMatch['score']['overs'] = 0;
              updatedMatch['score']['thisOver'] = [];
              
              updatedMatch['currentBatsmen'] = []; updatedMatch['currentBowler'] = null;
            } else {
              // Pair of innings just ended (2nd, 4th, 6th...)
              var prevInnings = inningsList[battingIdx - 1];
              if (currentInnings['runs'] == prevInnings['runs']) {
                 // TIE
                 updatedMatch['status'] = 'live'; 
                 _showSuperOverDialog();
                 _showSnackBar('Scores are Level! Match Tied.', isError: false);
              } else {
                  updatedMatch['status'] = 'completed';
                  _showSnackBar('Match Completed!', isError: false);
              }
          }
      }
    }
    else if (type == 'new_batsman') {
        // value = _toCamelCase(value); // Validation relaxed
        /*if (!battingSquad.contains(value)) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Player not in current batting team squad!'), backgroundColor: Colors.red));
           return;
        }*/
        List<dynamic> curBatsmen = updatedMatch['currentBatsmen'] ?? [];
        if (curBatsmen.isEmpty) {
            curBatsmen = [{'name': value, 'onStrike': true, 'runs': 0, 'balls': 0}, {'name': '', 'onStrike': false, 'runs': 0, 'balls': 0}];
        } else {
            int emptyIdx = curBatsmen.indexWhere((b) => b['name'] == '');
            if (emptyIdx != -1) {
                curBatsmen[emptyIdx] = {'name': value, 'onStrike': curBatsmen[emptyIdx]['onStrike'], 'runs': 0, 'balls': 0};
            } else {
                int outIdx = curBatsmen.indexWhere((b) => b['onStrike'] == true); 
                if (outIdx != -1) curBatsmen[outIdx] = {'name': value, 'onStrike': true, 'runs': 0, 'balls': 0};
            }
        }
        updatedMatch['currentBatsmen'] = curBatsmen;
        if (findBatIndex(value) == -1) (currentInnings['batting'] as List).add({'player': value, 'status': 'not out', 'runs': 0, 'balls': 0, 'fours': 0, 'sixes': 0, 'strikeRate': 0});
    }
    else if (type == 'new_bowler') {
        if (updatedMatch['currentBowler'] == value) {
           _showSnackBar('This bowler was already bowling! Select a different replacement.', isError: true);
           return;
        }
        if (updatedMatch['score']['lastOverBowler'] == value) {
           _showSnackBar('A bowler cannot bowl two overs in a row! This player bowled the previous over.', isError: true);
           return;
        }

        int bIdx = findBowlIndex(value);
        if (bIdx != -1) {
           var bowlerStats = currentBowling['bowling'][bIdx];
           if ((bowlerStats['overs'] as num).floor() >= 2) {
              _showSnackBar('A bowler cannot bowl more than 2 overs!', isError: true);
              return;
           }
        }

        updatedMatch['currentBowler'] = value;
        if (findBowlIndex(value) == -1) (currentBowling['bowling'] as List).add({'player': value, 'overs': 0, 'maidens': 0, 'runs': 0, 'wickets': 0, 'economy': 0});
    }
    else if (type == 'swap_strike') {
        List<dynamic> curBatsmen = updatedMatch['currentBatsmen'] ?? [];
        if (curBatsmen.length == 2) {
           curBatsmen[0]['onStrike'] = !curBatsmen[0]['onStrike'];
           curBatsmen[1]['onStrike'] = !curBatsmen[1]['onStrike'];
        }
        updatedMatch['currentBatsmen'] = curBatsmen;
    }
    else if (type == 'manual') {
       updatedMatch = value;
    }

    setState(() { match = updatedMatch; });
    _saveMatch();
  }

  String? _calculateMOM(Map<String, dynamic> m) {
    try {
      if (m['innings'] == null || (m['innings'] as List).length < 2) return null;
      
      Map<String, double> scores = {};
      
      for (var inn in (m['innings'] as List)) {
        for (var p in (inn['batting'] as List)) {
          String name = p['player'];
          scores[name] = (scores[name] ?? 0) + (p['runs'] as num).toDouble();
        }
        for (var p in (inn['bowling'] as List)) {
          String name = p['player'];
          scores[name] = (scores[name] ?? 0) + (p['wickets'] as num).toDouble() * 25.0; // Matching web (25)
        }
      }
      
      String? best; double max = -1;
      scores.forEach((name, s) { if (s > max) { max = s; best = name; } });
      return best;
    } catch (_) { return null; }
  }

  void _showSuperOverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.flash_on, color: Colors.orange),
            SizedBox(width: 10),
            Text('SUPER OVER', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('The scores are level! A Super Over is required to decide the winner.', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            SizedBox(height: 15),
            Text('• 1 Over per side\n• 2 Wickets per side\n• Chasing team bats first', style: GoogleFonts.outfit(color: Colors.grey[700], fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(
            child: Text('DECLARE TIE', style: GoogleFonts.outfit(color: Colors.grey[600])),
            onPressed: () {
              Navigator.pop(context);
              _handleDeclareTie();
            },
          ),
          ElevatedButton(
            child: Text('START SUPER OVER'),
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              Navigator.pop(context);
              _startSuperOver();
            },
          ),
        ],
      ),
    );
  }

  void _startSuperOver() {
    var updatedMatch = Map<String, dynamic>.from(match);
    List<dynamic> inningsList = List<dynamic>.from(updatedMatch['innings']);
    
    String nextBattingTeam;
    if (inningsList.length == 2) {
      // End of main match
      nextBattingTeam = inningsList[0]['team'];
    } else {
      // End of previous SO
      nextBattingTeam = inningsList[inningsList.length - 2]['team'];
    }
    
    // Add first innings of SO pair
    inningsList.add({
      'team': nextBattingTeam, 'runs': 0, 'wickets': 0, 'overs': 0, 'batting': [], 'bowling': [], 
      'extras': {'total': 0, 'wides': 0, 'noBalls': 0, 'byes': 0, 'legByes': 0}
    });
    
    updatedMatch['innings'] = inningsList;
    updatedMatch['score'] = {
      'battingTeam': nextBattingTeam,
      'runs': 0, 'wickets': 0, 'overs': 0,
      'thisOver': [],
      'target': null
    };
    updatedMatch['isSuperOver'] = true;
    updatedMatch['currentBatsmen'] = [];
    updatedMatch['currentBowler'] = null;
    updatedMatch['status'] = 'live';
    
    _handleUpdate('manual', updatedMatch);
    _showSnackBar('Super Over Started! ${nextBattingTeam} batting first.', isError: false);
  }

  void _handleDeclareTie() {
    var updatedMatch = Map<String, dynamic>.from(match);
    updatedMatch['status'] = 'completed';
    // MOM removed
    _handleUpdate('manual', updatedMatch);
    _showSnackBar('Match declared as a TIE!');
  }

  // --- UI COMPONENTS ---
  
  @override
  Widget build(BuildContext context) {
    bool isLive = match['status'] == 'live';
    bool isUpcoming = match['status'] == 'upcoming';

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('Admin Control Panel', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(
          icon: Icon(Icons.home),
          onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            tooltip: 'Refresh Data',
            onPressed: () {
               setState(() => isLoading = true);
               // Re-fetch match data from server
               ApiService.getMatch(match['_id'] ?? match['id']).then((data) {
                  setState(() {
                    match = data;
                    isLoading = false;
                  });
                  _showSnackBar('Match data refreshed');
               }).catchError((e) {
                  setState(() => isLoading = false);
                  _showSnackBar('Refresh failed: ${e.toString()}', isError: true);
               });
            },
          )
        ],
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [primaryColor, accentColor]),
          ),
        ),
        elevation: 0,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          bool isWide = constraints.maxWidth > 700;
          
          return SingleChildScrollView(
              child: Stack(
                children: [
                  Column(
                    children: [
                      _buildScoreCard(isWide),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: isWide ? 40 : 16, vertical: 20),
                        child: Column(
                          children: [
                            if (isUpcoming || !isLive) _buildUpcomingControls(),

                            if (isLive) ...[
                               if (match['score']['target'] != null && (match['currentBatsmen'] == null || (match['currentBatsmen'] as List).isEmpty))
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 20.0),
                                    child: _actionButton('2nd Innings Start', successColor, Icons.play_arrow, _showStartDialog),
                                  ),
                               _buildLiveStatus(isWide),
                               Divider(thickness: 1, height: 40),
                               _buildScoringGrid(isWide),
                            Divider(thickness: 1, height: 40),
                            _buildFOWPanel(),
                            SizedBox(height: 20),
                            // Additional Controls
                            SizedBox(height: 30),
                            _buildCorrectionPanel(isWide),
                            SizedBox(height: 15),
                            _buildAdvancedControls(isWide),
                            
                          ],
                          SizedBox(height: 20),
                          AppFooter(),
                          SizedBox(height: 40),
                        ], // Closing children list
                      ),
                    ),

                    ],
                  ),
                  if (_showBlast) 
                    Positioned.fill(
                      child: IgnorePointer(
                        child: _buildBoundaryAnimation(),
                      ),
                    ),
                ],
              ),
          );
        }
      ),
    );
  }

  Widget _buildAdvancedControls(bool isWide) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('QUICK ACTIONS', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
              SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: Icon(Icons.person_off),
                      label: Text('Retire Batsman'),
                      onPressed: () {
                         _handleUpdate('retire', null);
                         _showNewBatsmanDialog();
                      },
                      style: OutlinedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 12), foregroundColor: dangerColor),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: Icon(Icons.sync),
                      label: Text('Manual Sync'),
                      onPressed: _saveMatch,
                      style: OutlinedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 12)),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              Row(
                children: [
                   Expanded(
                    child: OutlinedButton.icon(
                      icon: Icon(Icons.refresh_outlined, color: Colors.teal),
                      label: Text('Change Bowler', style: GoogleFonts.outfit(color: Colors.teal)),
                      onPressed: _showNewBowlerDialog,
                      style: OutlinedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 12), side: BorderSide(color: Colors.teal)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
  }

  void _deleteLastBall() {
     if (match['history'] == null || (match['history'] as List).isEmpty) {
        _showSnackBar('No previous ball to delete!', isError: true);
        return;
     }
     
     // Get last state
     List<dynamic> history = (match['history'] as List<dynamic>).toList();
     var lastState = history.removeLast();
     
     setState(() {
        match = lastState;
        match['history'] = history; // Ensure history is updated (removed last item)
     });
     
     _saveMatch();
     _showSnackBar('Last action undone successfully!');
  }

  Widget _buildCorrectionPanel(bool isWide) {
    // Constraint: No modification after 1st innings (target set) usually, but allow STATUS override always
    // if (match['status'] == 'completed') return SizedBox.shrink(); // ALLOW View for Override
    
    bool isCompleted = match['status'] == 'completed' || match['status'] == 'cancelled' || match['status'] == 'abandoned';
    // Remove restriction for second innings (target set) to allow edits
    // bool isSecondInnings = (match['score']['target'] != null && match['score']['target'] > 0);

    bool isExpanded = false;
    return StatefulBuilder(builder: (context, setStateLocal) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Column(
          children: [
            ListTile(
              title: Text('🔧 CORRECTION PANEL', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              trailing: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
              onTap: () => setStateLocal(() => isExpanded = !isExpanded),
            ),
            if (isExpanded) Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _miniInput('Runs', match['score']['runs'].toString(), (v) {
                         int newRuns = int.tryParse(v) ?? 0;
                         if (newRuns < 0) { _showSnackBar('Runs cannot be negative', isError: true); return; }
                         var m = Map<String, dynamic>.from(match);
                         m['score']['runs'] = newRuns;
                         _handleUpdate('manual', m);
                      })),
                      SizedBox(width: 10),
                      Expanded(child: _miniInput('Wkts', match['score']['wickets'].toString(), (v) {
                         int newWkts = int.tryParse(v) ?? 0;
                         if (newWkts < 0 || newWkts > 10) { _showSnackBar('Wickets must be 0-10', isError: true); return; }
                         var m = Map<String, dynamic>.from(match);
                         m['score']['wickets'] = newWkts;
                         _handleUpdate('manual', m);
                      })),
                      SizedBox(width: 10),
                      Expanded(child: _miniInput('Overs', match['score']['overs'].toString(), (v) {
                         double newOvers = double.tryParse(v) ?? 0.0;
                         if (newOvers > (match['totalOvers'] as int)) { _showSnackBar('Overs cannot exceed ${match['totalOvers']}', isError: true); return; }
                         var m = Map<String, dynamic>.from(match);
                         m['score']['overs'] = newOvers;
                         _handleUpdate('manual', m);
                      })),
                    ],
                  ),
                  SizedBox(height: 15),
                  _buildDropdown('Batting Team', match['score']['battingTeam'], [match['teamA'], match['teamB']], (v) {
                      var m = Map<String, dynamic>.from(match);
                      if (m['score']['battingTeam'] != v) {
                          m['score']['battingTeam'] = v;
                          m['currentBatsmen'] = [];
                          m['currentBowler'] = null;
                      }
                      _handleUpdate('manual', m);
                  }),
                  SizedBox(height: 10),
                  _buildDropdown('Status Override', match['status'], ['upcoming', 'live', 'completed', 'cancelled', 'abandoned'], (v) {
                      var m = Map<String, dynamic>.from(match);
                      m['status'] = v;
                      // If cancelled/abandoned, we might want to clear target or specific things, but for now just status
                      _handleUpdate('status_override', m);
                  }),
                  

                    
                  SizedBox(height: 15),
                  Text('Current Batters (Correction)', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
                  SizedBox(height: 5),
                  Row(
                    children: [
                       Expanded(
                         child: _buildDropdown(
                           'Striker', 
                           (match['currentBatsmen'] as List).isNotEmpty ? match['currentBatsmen'][0]['name'] : '', 
                           match['score']['battingTeam'] == match['teamA'] ? match['teamASquad'] : match['teamBSquad'], 
                           (v) {
                             var m = Map<String, dynamic>.from(match);
                             List<dynamic> cb = List.from(m['currentBatsmen']);
                             if (cb.isNotEmpty) cb[0]['name'] = v;
                             m['currentBatsmen'] = cb;
                             _handleUpdate('manual', m);
                           }
                         )
                       ),
                       SizedBox(width: 10),
                       Expanded(
                         child: _buildDropdown(
                           'Non-Striker', 
                           (match['currentBatsmen'] as List).length > 1 ? match['currentBatsmen'][1]['name'] : '', 
                           match['score']['battingTeam'] == match['teamA'] ? match['teamASquad'] : match['teamBSquad'], 
                           (v) {
                             var m = Map<String, dynamic>.from(match);
                             List<dynamic> cb = List.from(m['currentBatsmen']);
                             if (cb.length > 1) cb[1]['name'] = v;
                             m['currentBatsmen'] = cb;
                             _handleUpdate('manual', m);
                           }
                         )
                       ),
                    ],
                  ),

                  if (match['status'] == 'cancelled' || match['status'] == 'abandoned' || match['status'] == 'completed') ...[
                      SizedBox(height: 10),
                      Text('Result / Cancellation Reason', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
                      SizedBox(height: 5),
                      DropdownButtonFormField<String>(
                         decoration: InputDecoration(
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            filled: true,
                            fillColor: Colors.white
                         ),
                         value: null, 
                         hint: Text(match['manOfTheMatch'] != null && (match['manOfTheMatch'] as String).contains('Match') || (match['manOfTheMatch'] as String).contains('Rain') ? match['manOfTheMatch'] : 'Select Reason...'),
                         items: [
                           'Rain - Match Cancelled', 
                           'Wet Outfield - Abandoned', 
                           'Bad Light - Stopped',
                           'Walkover - Team A Won',
                           'Walkover - Team B Won',
                           'Team Not Arrived',
                           'Technical Issue',
                           'Postponed'
                         ].map((s) => DropdownMenuItem(value: s, child: Text(s, style: GoogleFonts.outfit(fontSize: 12)))).toList(),
                         onChanged: (v) {
                            var m = Map<String, dynamic>.from(match);
                            m['manOfTheMatch'] = v; 
                            if (v!.contains('Walkover')) m['status'] = 'completed'; 
                            _handleUpdate('status_override', m);
                         }
                      ),
                      ]
                  ]
                  )
              ),
            SizedBox(height: 10),
            ListTile(
              title: Text('Start Super Over', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
              leading: Icon(Icons.flash_on, color: Colors.deepPurple),
              onTap: () {
                 _showSuperOverDialog();
              },
            )
          ],
        ),
      );
    });
  }

  Widget _miniInput(String label, String value, Function(String) onChange) {
    return TextField(
      decoration: InputDecoration(labelText: label, border: OutlineInputBorder(), contentPadding: EdgeInsets.all(8)),
      keyboardType: TextInputType.numberWithOptions(decimal: true),
      controller: TextEditingController(text: value)..selection = TextSelection.collapsed(offset: value.length),
      onSubmitted: onChange,
    );
  }

  Widget _buildScoreCard(bool isWide) {
    var score = match['score'] ?? {};
    bool isSecondInnings = score['target'] != null;
    num runs = score['runs'] ?? 0;
    num wickets = score['wickets'] ?? 0;
    num overs = score['overs'] ?? 0;
    num totalOvers = match['totalOvers'] ?? 20;
    num target = score['target'] ?? 0;

    int runsNeeded = isSecondInnings ? (target.toInt() - runs.toInt()) : 0;
    // Calculate balls remaining safely
    int ballsRemaining = 0;
    if (isSecondInnings) {
       int totalBalls = (totalOvers * 6).toInt();
       int bowledBalls = (overs.floor() * 6) + ((overs * 10) % 10).round().toInt();
       ballsRemaining = totalBalls - bowledBalls;
    }
    double rrr = (ballsRemaining > 0 && runsNeeded > 0) ? (runsNeeded / ballsRemaining) * 6 : 0;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(horizontal: isWide ? 40 : 16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: primaryColor.withOpacity(0.5), blurRadius: 10, offset: Offset(0, 5))]
      ),
      child: Column(
        children: [
          Text(
            '${match['teamA']} vs ${match['teamB']}'.toUpperCase(),
            style: GoogleFonts.outfit(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2),
          ),
          SizedBox(height: 10),
          Text(
            '$runs/$wickets',
            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: isWide ? 60 : 48),
          ),
          Text(
            'OVERS: $overs / $totalOvers',
            style: GoogleFonts.outfit(color: Colors.yellowAccent, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1),
          ),
          SizedBox(height: 15),
          
          // NEW STATUS COLUMN
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                 if (match['toss'] != null)
                   Text('TOSS: ${match['toss']['winner']} ELECTED TO ${match['toss']['decision']}'.toUpperCase(), style: GoogleFonts.outfit(color: Colors.white.withOpacity(0.9), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                 if (isSecondInnings) 
                   Padding(
                     padding: const EdgeInsets.only(top: 6.0),
                     child: Text('$runsNeeded RUNS NEEDED FROM $ballsRemaining BALLS'.toUpperCase(), style: GoogleFonts.outfit(color: Colors.amberAccent, fontWeight: FontWeight.w900, fontSize: 11)),
                   ),
                 if (match['isSuperOver'] == true) 
                   Padding(
                     padding: const EdgeInsets.only(top: 6.0),
                     child: Text('SUPER OVER', style: GoogleFonts.outfit(color: Colors.purpleAccent, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 3)),
                   ),
              ],
            ),
          ),

          SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
                child: Text('CRR: ${(overs > 0 ? (runs / (overs.floor() + (overs % 1) * 1.666)).toStringAsFixed(2) : "0.00")}', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: isWide ? 16 : 14)),
              ),
              if (isSecondInnings && (runs > 0 || overs > 0)) ...[
                SizedBox(width: 10),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: warningColor, borderRadius: BorderRadius.circular(8)),
                  child: Text('RRR: ${rrr.toStringAsFixed(2)}', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: isWide ? 15 : 13)),
                ),
              ],
              if (isSecondInnings) ...[
                SizedBox(width: 10),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: dangerColor, borderRadius: BorderRadius.circular(8)),
                  child: Text('TARGET: $target', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: isWide ? 15 : 13)),
                ),
              ],
            ],
          )
        ],
      ),
    );
  }

  Widget _buildBoundaryAnimation() {
    return Container(
      color: Colors.black45,
      child: Center(
        child: TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 1000),
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, value, child) {
            return Stack(
              alignment: Alignment.center,
              children: [
                // Inner Blast
                Transform.scale(
                  scale: 0.5 + value * 2.5,
                  child: Opacity(
                    opacity: (1.0 - value).clamp(0.0, 1.0),
                    child: Container(
                      width: 200, height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [_lastBoundary == 6 ? successColor : warningColor, Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                ),
                // Text
                Transform.scale(
                  scale: 0.8 + value * 0.5,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_lastBoundary.toString(), style: GoogleFonts.outfit(fontSize: 120, fontWeight: FontWeight.w900, color: Colors.white, shadows: [Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 40)])),
                      Text(_lastBoundary == 6 ? 'MASSIVE SIX!' : 'FANTASTIC FOUR!', style: GoogleFonts.outfit(fontSize: 30, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2, shadows: [Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 20)])),
                    ],
                  ),
                ),
                // Particles
                ...List.generate(8, (i) {
                  double angle = (i * 45) * 3.14 / 180;
                  return Transform.translate(
                    offset: Offset(math.cos(angle) * value * 200, math.sin(angle) * value * 200),
                    child: Opacity(
                      opacity: (1.0 - value).clamp(0.0, 1.0),
                      child: Icon(Icons.star, color: warningColor, size: 20 + value * 20),
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFOWPanel() {
    String battingTeamName = match['score']['battingTeam'] ?? match['teamA'];
    var currentInnings = (match['innings'] as List).firstWhere((inn) => inn['team'] == battingTeamName, orElse: () => null);
    if (currentInnings == null || currentInnings['fallOfWickets'] == null || (currentInnings['fallOfWickets'] as List).isEmpty) return SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('FALL OF WICKETS', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
        SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: (currentInnings['fallOfWickets'] as List).map((f) => Container(
              margin: EdgeInsets.only(right: 10),
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade300)),
              child: Text('${f['wicket']}-${f['runs']} (${f['player']})', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold)),
            )).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildUpcomingControls() {
    bool isCompleted = match['status'] == 'completed';
    String? winnerMsg;
    if (isCompleted) {
      winnerMsg = _calculateWinnerMsg(match);
    }

    return Column(
      children: [
        if (!isCompleted) ...[
          _actionButton('👥 MANAGE SQUADS', Colors.blueGrey, Icons.group, () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => SquadScreen(match: match)));
              setState(() {}); // Refresh state after return
          }),
          SizedBox(height: 15),
        ],

        /* REMOVED AUTO SUPER OVER PROMPT
        if (isCompleted && match['isSuperOver'] != true && (match['innings'] as List).length >= 2 && 
            (match['innings'][0]['runs'] == match['innings'][1]['runs'])) ...[
             // ...
        ],
        */

        if (isCompleted) ...[
          Container(
             width: double.infinity,
             padding: EdgeInsets.all(16),
             decoration: BoxDecoration(
               gradient: LinearGradient(colors: [successColor, accentColor]),
               borderRadius: BorderRadius.circular(15),
               boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))]
             ),
             child: Column(
               children: [
                 Text('MATCH COMPLETED', style: GoogleFonts.outfit(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
                 SizedBox(height: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(winnerMsg ?? 'MATCH DRAWN', style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900), textAlign: TextAlign.center),
                  ),
               ],
             ),
           ),
           SizedBox(height: 20),
        ] else if (match['toss'] == null || match['toss']['winner'] == null)
           _actionButton('🪙 CONDUCT TOSS', warningColor, Icons.monetization_on, () {
              // Block if current time is before match scheduled time
               // Block if current time is before match scheduled time
               // Block if current time is before match scheduled time
               if (match['date'] != null) {
                  try {
                    // Parse date and convert to local time
                    DateTime scheduled = DateTime.parse(match['date'].toString()).toLocal(); 
                    
                    // Allow 15 mins early buffer for prep
                    if (DateTime.now().add(Duration(minutes: 15)).isBefore(scheduled)) {
                        _showSnackBar('Wait! Match starts at ${DateFormat('hh:mm a').format(scheduled)}', isError: true);
                        return;
                    }
                  } catch (e) {
                    print("Date Parse Error: $e");
                  }
               }
               _showTossDialog();
           }, textColor: Colors.black)
        else if (match['toss'] != null && match['toss']['winner'] != null) ...[
           Container(
             padding: EdgeInsets.all(12),
             decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.amber)),
             child: Row(children: [Icon(Icons.info, color: Colors.amber[800]), SizedBox(width: 10), Expanded(child: Text('Toss won by ${match['toss']['winner']} elected to ${match['toss']['decision']}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.amber[900])))]),
           ),
           SizedBox(height: 15),
           _actionButton('1st Innings Start', successColor, Icons.play_arrow, () {
                // Block if current time is before match scheduled time
                // Block if current time is before match scheduled time
               if (match['date'] != null) {
                  try {
                    DateTime scheduled = DateTime.parse(match['date'].toString()).toLocal();
                    
                    if (DateTime.now().add(Duration(minutes: 15)).isBefore(scheduled)) {
                        _showSnackBar('Wait! Match starts at ${DateFormat('hh:mm a').format(scheduled)}', isError: true);
                        return;
                    }
                  } catch (e) { }
               }
               _showStartDialog();
           }),
        ]
      ],
    );
  }

  String _calculateWinnerMsg(Map<String, dynamic> m) {
    try {
      if (m['innings'] == null || (m['innings'] as List).length < 2) return "MATCH COMPLETED";
      List innings = m['innings'];
      int lastIdx = innings.length - 1;
      bool isSuperOver = innings.length > 2;
      
      var inn1 = innings[0], inn2 = innings[1];
      if (isSuperOver) {
        inn1 = innings[lastIdx - 1];
        inn2 = innings[lastIdx];
      }

      int r1 = (inn1['runs'] ?? 0) as int;
      int r2 = (inn2['runs'] ?? 0) as int;
      
      if (r1 > r2) {
        if (isSuperOver) return "MATCH TIED | ${inn1['team'].toString().toUpperCase()} WON VIA SUPER OVER";
        return "${inn1['team'].toString().toUpperCase()} WON BY ${r1 - r2} RUNS";
      }
      if (r2 > r1) {
        if (isSuperOver) return "MATCH TIED | ${inn2['team'].toString().toUpperCase()} WON VIA SUPER OVER";
        int wkts = 10 - ((inn2['wickets'] ?? 0) as num).toInt();
        return "${inn2['team'].toString().toUpperCase()} WON BY $wkts WICKETS";
      }
      return isSuperOver ? "MATCH TIED | SUPER OVER DRAWN" : "MATCH TIED";
    } catch (_) { return "MATCH COMPLETED"; }
  }
  
  Widget _buildLiveStatus(bool isWide) {
     List<dynamic> batsmen = (match['currentBatsmen'] as List?) ?? [];
     String bowler = match['currentBowler'] ?? '-';
     var score = match['score'] ?? {};
     var thisOver = (score['thisOver'] as List?) ?? [];
     
     return Row(
       children: [
         Expanded(
           child: Card(
             elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
             child: Padding(
               padding: EdgeInsets.all(isWide ? 20 : 12.0),
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('BATTING', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.blueGrey, letterSpacing: 1.2)),
                    SizedBox(height: 10),
                     ...batsmen.map((b) => Padding(
                       padding: const EdgeInsets.symmetric(vertical: 6.0),
                       child: Row(
                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                         children: [
                           Expanded(child: Text(b['name'].isEmpty ? '(WAITING...)' : b['name'].toUpperCase(), style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: isWide ? 16 : 14, color: b['onStrike'] ? primaryColor : Colors.black54), overflow: TextOverflow.ellipsis)),
                           Text(b['name'].isEmpty ? '' : '${b['runs']} (${b['balls']})', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: isWide ? 16 : 14, color: b['onStrike'] ? primaryColor : null)),
                         ],
                       ),
                     )),
                     if (batsmen.isNotEmpty && batsmen.any((b) => b['name'].isNotEmpty))
                       Divider(color: Colors.grey.withOpacity(0.1)),
                     if (batsmen.length == 2 && batsmen.every((b) => b['name'].isNotEmpty))
                       Center(
                         child: TextButton.icon(
                           onPressed: () => _handleUpdate('swap_strike', null),
                           icon: Icon(Icons.swap_horiz_rounded, size: 16, color: primaryColor),
                           label: Text('SWAP STRIKE', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: primaryColor)),
                           style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size(0, 30)),
                         ),
                       ),
                   ],
               ),
             ),
           ),
         ),
         SizedBox(width: isWide ? 20 : 10),
         Expanded(
           child: Card(
             elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
             child: Padding(
               padding: EdgeInsets.all(isWide ? 20 : 12.0),
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('BOWLING', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.blueGrey, letterSpacing: 1.2)),
                    SizedBox(height: 10),
                    Text(bowler.toUpperCase(), style: GoogleFonts.outfit(fontSize: isWide ? 20 : 16, fontWeight: FontWeight.w900, color: primaryColor), overflow: TextOverflow.ellipsis),
                    SizedBox(height: 8),
                    Text('ACTIVE OVER', style: GoogleFonts.outfit(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: thisOver.map((b) => Container(
                          margin: EdgeInsets.only(right: 6),
                          padding: EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: b.toString().contains('W') || b.toString() == 'OUT' ? dangerColor.withOpacity(0.1) : (['4','6'].contains(b.toString()) ? successColor.withOpacity(0.1) : Colors.grey.shade100),
                            shape: BoxShape.circle,
                            border: Border.all(color: b.toString().contains('W') || b.toString() == 'OUT' ? dangerColor.withOpacity(0.2) : (['4','6'].contains(b.toString()) ? successColor.withOpacity(0.2) : Colors.grey.shade200))
                          ),
                          child: Text(b.toString(), style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: b.toString().contains('W') ? dangerColor : (['4','6'].contains(b.toString()) ? successColor : Colors.black87))),
                        )).toList(),
                     ),
                    )
                  ],
               ),
             ),
           ),
         ),
       ],
     );
  }

  Widget _buildScoringGrid(bool isWide) {
    double width = MediaQuery.of(context).size.width;
    int crossAxisCount = isWide ? 6 : 3;
    double aspectRatio = isWide ? 1.6 : 1.4;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
             Expanded(child: _actionButton('SQUADS', Colors.blueGrey, Icons.group, () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => SquadScreen(match: match))); setState(() {}); }, isSmall: true)),
             SizedBox(width: 8),
             Expanded(child: _actionButton('BOWLER', Colors.teal, Icons.refresh, () => _showNewBowlerDialog(), isSmall: true)),
             SizedBox(width: 8),
             Expanded(child: _actionButton('UNDO', dangerColor, Icons.undo, _deleteLastBall, isSmall: true)),
          ],
        ),
        SizedBox(height: 20),
        GridView.count(
          physics: NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: aspectRatio,
          children: [
            _scoreTile('0', Colors.white, () => _handleUpdate('runs', 0)),
            _scoreTile('1', Colors.grey.shade200, () => _handleUpdate('runs', 1)),
            _scoreTile('2', Colors.grey.shade200, () => _handleUpdate('runs', 2)),
            _scoreTile('3', Colors.grey.shade200, () => _handleUpdate('runs', 3)),
            _scoreTile('4', Color(0xFFE3F2FD), () => _handleUpdate('runs', 4), textColor: primaryColor),
            _scoreTile('6', Color(0xFFE8F5E9), () => _handleUpdate('runs', 6), textColor: successColor),
            _scoreTile('WD', Colors.orange.shade50, () => _handleUpdate('extra', 'w'), textColor: Colors.orange),
            _scoreTile('NB', Colors.orange.shade50, () => _handleUpdate('extra', 'nb'), textColor: Colors.orange),
            _scoreTile('BYE', Colors.blue.shade50, () => _handleUpdate('extra', 'b'), textColor: Colors.blue),
            _scoreTile('LB', Colors.green.shade50, () => _handleUpdate('extra', 'lb'), textColor: Colors.green),
            _scoreTile('OUT', Colors.red.shade50, _showWicketDialog, textColor: dangerColor, isBold: true),
            _scoreTile('RET', Colors.lightBlue.shade50, () {
               _handleUpdate('retire', null);
               _showNewBatsmanDialog();
            }, textColor: Colors.blue.shade700, isBold: true),
          ],
        ),
      ],
    );
  }

  Widget _scoreTile(String label, Color bg, VoidCallback onTap, {Color textColor = Colors.black, bool isBold = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: Offset(0, 4))],
          border: Border.all(color: textColor.withOpacity(0.1)),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionButton(String label, Color color, IconData icon, VoidCallback onTap, {bool isSmall = false, Color? textColor}) {
    return SizedBox(
      height: isSmall ? 45 : 55,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor ?? Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
          shadowColor: color.withOpacity(0.3),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: isSmall ? 14 : 20),
            SizedBox(width: 8),
            Text(label, style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: isSmall ? 11 : 14, letterSpacing: 1)),
          ],
        ),
      ),
    );
  }

  void _showTossDialog() {
    String winner = match['teamA'];
    String decision = 'bat';
    showDialog(context: context, builder: (context) {
       return StatefulBuilder(builder: (context, setState) {
         return AlertDialog(
           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
           title: Text('🪙 Coin Toss', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
           content: Column(
             mainAxisSize: MainAxisSize.min,
             children: [
               _buildDropdown('Winner', winner, [match['teamA'], match['teamB']], (v) => setState(() => winner = v)),
               SizedBox(height: 15),
               _buildDropdown('Decision', decision, ['bat', 'bowl'], (v) => setState(() => decision = v)),
             ],
           ),
           actions: [
             TextButton(child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.grey)), onPressed: () => Navigator.pop(context)),
             ElevatedButton(child: Text('Confirm'), style: ElevatedButton.styleFrom(backgroundColor: primaryColor), onPressed: () {
               String battingTeam = decision == 'bat' ? winner : (winner == match['teamA'] ? match['teamB'] : match['teamA']);
               var newMatch = Map<String, dynamic>.from(match);
               newMatch['toss'] = {'winner': winner, 'decision': decision};
               newMatch['score'] = {'battingTeam': battingTeam, 'runs': 0, 'wickets': 0, 'overs': 0};
               _handleUpdate('manual', newMatch);
               Navigator.pop(context);
             })
           ],
         );
       });
    });
  }

  void _showStartDialog() {
    var score = match['score'] ?? {'battingTeam': match['teamA']};
    String battingTeam = score['battingTeam'] ?? match['teamA'];
    List<dynamic> batsList = match[battingTeam == match['teamA'] ? 'teamASquad' : 'teamBSquad'] ?? [];
    String bowlingTeam = battingTeam == match['teamA'] ? match['teamB'] : match['teamA'];
    List<dynamic> bowlList = match[bowlingTeam == match['teamA'] ? 'teamASquad' : 'teamBSquad'] ?? [];
    
    if (batsList.length < 11 || bowlList.length < 11) {
      _showSnackBar('Both teams must have 11 players selected in Squads!', isError: true);
      return;
    }

    String s = batsList.isNotEmpty ? batsList[0] : '';
    String ns = batsList.length > 1 ? batsList[1] : '';
    String b = bowlList.isNotEmpty ? bowlList[0] : '';
    
    showDialog(context: context, builder: (context) {
      return StatefulBuilder(builder: (context, setState) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('🚀 Start Match', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: primaryColor)),
          content: SingleChildScrollView(
            child: Column(
               mainAxisSize: MainAxisSize.min,
               children: [
                 Text('Set the initial players for the game.', style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12)),
                 SizedBox(height: 15),
                 _buildDropdown('Striker', s, batsList, (v) => setState(() => s = v)),
                 SizedBox(height: 10),
                 _buildDropdown('Non-Striker', ns, batsList, (v) => setState(() => ns = v)),
                 SizedBox(height: 10),
                 _buildDropdown('Opening Bowler', b, bowlList, (v) => setState(() => b = v)),
               ],
            ),
          ),
          actions: [
            TextButton(child: Text('Cancel'), onPressed: () => Navigator.pop(context)),
            ElevatedButton(
              child: isSaving ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text('START GAME'), 
              style: ElevatedButton.styleFrom(
                backgroundColor: successColor, 
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
              ), 
              onPressed: () {
                if (s == ns) {
                  _showSnackBar('Striker and Non-Striker must be different!', isError: true);
                  return;
                }
                _handleUpdate('init', {'s': s, 'ns': ns, 'b': b});
                Navigator.pop(context);
              }
            )
          ],
        );
      });
    });
  }
  
  void _showWicketDialog() {
    String type = 'caught';
    String fielder = '';
    String battingTeam = match['score']['battingTeam'];
    String bowlingTeam = battingTeam == match['teamA'] ? match['teamB'] : match['teamA'];
    List<dynamic> fieldSquad = match[bowlingTeam == match['teamA'] ? 'teamASquad' : 'teamBSquad'] ?? [];
    
    List<dynamic> batsmen = match['currentBatsmen'] ?? [];
    String strikerName = batsmen.firstWhere((b) => b['onStrike'] == true, orElse: () => {'name': ''})['name'];
    String nonStrikerName = batsmen.firstWhere((b) => b['onStrike'] == false, orElse: () => {'name': ''})['name'];
    String whoOut = strikerName;
    bool crossed = false;
    int runsCompleted = 0;
    String ballStatus = 'normal';

    showDialog(context: context, builder: (context) {
       return StatefulBuilder(builder: (context, setState) {
         return AlertDialog(
           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
           title: Text('☝️ Wicket Details', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: dangerColor)),
           content: SingleChildScrollView(
             child: Column(
               mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDropdown('Dismissal Type', type.toUpperCase(), ['BOWLED', 'CAUGHT', 'RUN OUT', 'LBW', 'STUMPED', 'HIT WICKET', 'RETIRED HURT'], (v) => setState(() => type = v.toLowerCase())),
                 SizedBox(height: 15),
                 if (['caught', 'run out', 'stumped'].contains(type.toLowerCase()))
                    _buildDropdown('Fielder', fielder.isEmpty && fieldSquad.isNotEmpty ? (fielder = fieldSquad[0]) : fielder, fieldSquad, (v) => setState(() => fielder = v)),
                 if (['run out', 'stumped'].contains(type.toLowerCase())) ... [
                    SizedBox(height: 15),
                    _buildDropdown('Ball Category', ballStatus.toUpperCase(), ['NORMAL', 'WIDE', if (type.toLowerCase() == 'run out') 'NO-BALL', if (type.toLowerCase() == 'run out') 'MANKAD'], (v) => setState(() => ballStatus = v.toLowerCase())),
                 ],

                 if (type.toLowerCase() == 'run out') ...[
                    SizedBox(height: 15),
                    _buildDropdown('Who is Out?', whoOut, [strikerName, nonStrikerName].where((n) => n.isNotEmpty).toList(), (v) {
                       if (ballStatus == 'mankad' && v == strikerName) {
                         _showSnackBar('Mankad only applies to non-striker!', isError: true);
                         return;
                       }
                       setState(() => whoOut = v);
                    }),
                    if (ballStatus != 'mankad') ...[
                       SizedBox(height: 10),
                       Row(
                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                         children: [
                           Text('Batters Crossed?', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
                           Switch(value: crossed, activeColor: primaryColor, onChanged: (v) => setState(() => crossed = v)),
                         ],
                       ),
                       _buildDropdown('Runs Completed', runsCompleted.toString(), ['0', '1', '2', '3'], (v) => setState(() => runsCompleted = int.parse(v))),
                    ]
                 ]
               ],
             ),
           ),
           actions: [
             TextButton(child: Text('Cancel'), onPressed: () => Navigator.pop(context)),
             ElevatedButton(child: Text('CONFIRM OUT'), style: ElevatedButton.styleFrom(backgroundColor: dangerColor, foregroundColor: Colors.white), onPressed: () {
                _handleUpdate('wicket', 0, {
                  'type': type, 
                  'fielder': fielder,
                  'whoOut': whoOut,
                  'crossed': crossed,
                  'runs': runsCompleted,
                  'ballStatus': ballStatus
                });
                Navigator.pop(context);
                _showNewBatsmanDialog();
             })
           ],
         );
       });
    });
  }
  
    void _showNewBatsmanDialog() {
        String battingTeam = match['score']['battingTeam'];
        List<dynamic> squad = match[battingTeam == match['teamA'] ? 'teamASquad' : 'teamBSquad'] ?? [];
        
        // Find batting innings
        List<dynamic> inningsList = match['innings'] ?? [];
        int batIdx = inningsList.indexWhere((inn) => inn['team'] == battingTeam);
        List<dynamic> bStats = batIdx != -1 ? (inningsList[batIdx]['batting'] ?? []) : [];
        List<String> alreadyBatted = bStats.map((p) => p['player'].toString()).toList();
        
        // Players who haven't come to bat yet OR retired hurt players (Law 25.4)
        List<dynamic> availableBatsmen = squad.where((p) {
           var stats = bStats.firstWhere((s) => s['player'] == p, orElse: () => null);
           if (stats == null) return true; // Hasn't batted
           return stats['status'] == 'retired hurt'; // Can return to bat
        }).toList();
        
        if (availableBatsmen.isEmpty) {
          _showSnackBar('No more batsmen available in the squad!', isError: true);
          return;
        }

        String nextBat = availableBatsmen[0];
        
        showDialog(context: context, barrierDismissible: false, builder: (context) {
           return StatefulBuilder(builder: (context, setState) {
              return AlertDialog(
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                 title: Text('🏏 New Batsman', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                 content: Column(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                     Text('Select the next player from ${battingTeam}\'s squad.', style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12)),
                     SizedBox(height: 15),
                     _buildDropdown('Select Player', nextBat, availableBatsmen, (v) => setState(()=> nextBat = v)),
                   ],
                 ),
                  actions: [
                    TextButton(
                      child: Text('CANCEL & UNDO', style: GoogleFonts.outfit(color: Colors.red, fontWeight: FontWeight.bold)), 
                      onPressed: () {
                        Navigator.pop(context);
                        _deleteLastBall();
                      }
                    ),
                    ElevatedButton(
                      child: Text('CONFIRM & RESUME'), 
                      style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), 
                      onPressed: () {
                        _handleUpdate('new_batsman', nextBat);
                        Navigator.pop(context);
                      }
                    )
                  ],
              );
           });
        });
    }

  String _toCamelCase(String text) {
    if (text.isEmpty) return text;
    return text.trim().split(' ').map((word) {
      if (word.isEmpty) return '';
      if (word.length == 1) return word.toUpperCase();
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  void _showNewBowlerDialog({bool isRetirement = false}) {
      String battingTeam = match['score']['battingTeam'];
      String bowlingTeam = battingTeam == match['teamA'] ? match['teamB'] : match['teamA'];
      String currentBowler = match['currentBowler'] ?? '';
      List<dynamic> bowlList = match[bowlingTeam == match['teamA'] ? 'teamASquad' : 'teamBSquad'] ?? [];
      
      // Filter out current bowler
      List<dynamic> filteredBowlList = bowlList.where((p) => p != currentBowler).toList();
      if (filteredBowlList.isEmpty) filteredBowlList = bowlList; 

      String nextBowl = filteredBowlList.isNotEmpty ? filteredBowlList[0] : '';
      
      // Calculate remaining balls if mid-over
      double currentOvers = (match['score']['overs'] as num).toDouble();
      int ballsBowledInOver = ((currentOvers * 10) % 10).round();
      int ballsRemaining = 6 - ballsBowledInOver;
      bool isMidOver = ballsBowledInOver > 0 && ballsBowledInOver < 6;

      showDialog(context: context, builder: (context) {
         return StatefulBuilder(builder: (context, setState) {
            return AlertDialog(
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
               title: Text(isRetirement ? '🚑 Replace Bowler' : '⚾ New Bowler', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.teal)),
               content: Column(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   Text(
                     isRetirement 
                        ? 'Select a bowler to complete the remaining $ballsRemaining balls.'
                        : (isMidOver ? 'Current over incomplete. Select replacement to bowl remaining $ballsRemaining balls.' : 'Select which player will bowl the next over.'),
                     style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12)
                   ),
                   SizedBox(height: 15),
                   _buildDropdown('Select Bowler', nextBowl, filteredBowlList, (v) => setState(()=> nextBowl = v)),
                 ],
               ),
                actions: [
                  TextButton(
                    child: Text('CANCEL & UNDO', style: GoogleFonts.outfit(color: Colors.red, fontWeight: FontWeight.bold)), 
                    onPressed: () {
                      Navigator.pop(context);
                      _deleteLastBall();
                    }
                  ),
                 ElevatedButton(
                   child: Text(isRetirement || isMidOver ? 'RESUME OVER' : 'START OVER'), 
                   style: ElevatedButton.styleFrom(
                     backgroundColor: Colors.teal, 
                     foregroundColor: Colors.white,
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                   ), 
                   onPressed: () {
                     _handleUpdate('new_bowler', nextBowl);
                     Navigator.pop(context);
                   }
                 )
               ],
            );
         });
      });
  }

  Widget _buildDropdown(String label, String value, List<dynamic> items, Function(String) onChanged) {
     return Container(
       decoration: BoxDecoration(
         color: Colors.white,
         borderRadius: BorderRadius.circular(10),
         border: Border.all(color: Colors.grey.shade300)
       ),
       padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           Text(label, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
           DropdownButtonHideUnderline(
             child: DropdownButton<String>(
               value: (items.contains(value)) ? value : null,
               hint: Text('Select...'),
               isExpanded: true,
               icon: Icon(Icons.arrow_drop_down_circle, color: primaryColor),
               items: items.map<DropdownMenuItem<String>>((v) => DropdownMenuItem(
                 value: v.toString(), 
                 child: Text(_toCamelCase(v.toString()), style: GoogleFonts.outfit(fontWeight: FontWeight.bold))
               )).toList(),
               onChanged: (v) => onChanged(v!),
             ),
           ),
         ],
       ),
     );
  }

}
