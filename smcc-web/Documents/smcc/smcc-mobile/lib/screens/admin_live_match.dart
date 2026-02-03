import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'squad_screen.dart';
import '../widgets/app_footer.dart';

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

  final Color primaryColor = Color(0xFF1E3C72); // Deep Blue
  final Color accentColor = Color(0xFF2A5298); // Lighter Blue
  final Color successColor = Color(0xFF28A745); // Green
  final Color warningColor = Color(0xFFFFC107); // Amber/Yellow
  final Color dangerColor = Color(0xFFDC3545); // Red

  bool _showBlast = false;
  int _lastBoundary = 0;

  @override
  void initState() {
    super.initState();
    match = widget.matchData;
  }

  Future<void> _saveMatch() async {
    setState(() => isLoading = true);
    try {
      await ApiService.updateMatch((match['_id'] ?? match['id']).toString(), match);
      _showSnackBar('Match state saved successfully!');
    } catch (e) {
      _showSnackBar(e.toString().replaceAll('Exception: ', ''), isError: true);
    } finally {
      setState(() {
        isLoading = false;
        isSaving = false;
      });
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error_outline : Icons.check_circle_outline, color: Colors.white),
            SizedBox(width: 10),
            Expanded(child: Text(message, style: TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
        backgroundColor: isError ? Color(0xFFC62828) : Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.all(16),
      )
    );
  }

  Future<void> _handleUpdate(String type, dynamic value, [Map<String, dynamic>? params]) async {
    setState(() => isSaving = true);
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
    int battingIdx = inningsList.indexWhere((inn) => inn['team'] == battingTeamName);
    if (battingIdx == -1) battingIdx = 0; 
    int bowlingIdx = battingIdx == 0 ? 1 : 0;
    
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

      if (!battingSquad.contains(s) || !battingSquad.contains(ns)) {
        _showSnackBar('Batsmen must belong to the batting team squad!', isError: true);
        return;
      }
      if (!bowlingSquad.contains(b)) {
        _showSnackBar('Bowler must belong to the bowling team squad!', isError: true);
        return;
      }

      if (findBatIndex(s) == -1) (currentInnings['batting'] as List).add({'player': s, 'status': 'not out', 'runs': 0, 'balls': 0, 'fours': 0, 'sixes': 0, 'strikeRate': 0});
      if (findBatIndex(ns) == -1) (currentInnings['batting'] as List).add({'player': ns, 'status': 'not out', 'runs': 0, 'balls': 0, 'fours': 0, 'sixes': 0, 'strikeRate': 0});
      if (findBowlIndex(b) == -1) (currentBowling['bowling'] as List).add({'player': b, 'overs': 0, 'maidens': 0, 'runs': 0, 'wickets': 0, 'economy': 0});
      
      updatedMatch['currentBatsmen'] = [
        {'name': s, 'onStrike': true, 'runs': 0, 'balls': 0},
        {'name': ns, 'onStrike': false, 'runs': 0, 'balls': 0}
      ];
      updatedMatch['currentBowler'] = b;
      updatedMatch['status'] = 'live';
      if (updatedMatch['score']['battingTeam'] == null) updatedMatch['score']['battingTeam'] = updatedMatch['teamA'];
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

         if (completedRuns > 0) {
            currentInnings['runs'] += completedRuns;
            currentInnings['batting'][sIdx]['runs'] += completedRuns;
            currentBowling['bowling'][bIdx]['runs'] += completedRuns;
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
         currentInnings['batting'][sIdx]['balls'] += 1; 

         // Update currentBatsmen: mark out player slot as empty
         List<dynamic> cb = List<dynamic>.from(updatedMatch['currentBatsmen'] ?? []);
         for (int i = 0; i < cb.length; i++) {
            if (cb[i]['name'] == outPlayerName) {
               cb[i]['name'] = ''; 
               // If run out, the one who is out might be the onStrike one or not.
               // We need to keep one slot empty for the new batsman.
            } else if (crossed) {
               cb[i]['onStrike'] = !cb[i]['onStrike'];
            }
         }
         updatedMatch['currentBatsmen'] = cb;

         if (updatedMatch['score']['thisOver'] == null) updatedMatch['score']['thisOver'] = [];
         (updatedMatch['score']['thisOver'] as List).add('W');

         // Track Fall of Wicket
         if (currentInnings['fow'] == null) currentInnings['fow'] = [];
         (currentInnings['fow'] as List).add({
           'wicket': currentInnings['wickets'],
           'runs': currentInnings['runs'],
           'overs': currentInnings['overs'],
           'player': outPlayerName
         });
      } else if (type == 'retire') {
         currentInnings['batting'][sIdx]['status'] = 'retired hurt';
         // Ball doesn't count if retired? Depends on rules, usually treated as not out but replaced.
      }

      if (ballCounts) {
         double overs = (currentInnings['overs'] as num).toDouble();
         int balls = ((overs.floor() * 6) + ((overs * 10) % 10).round()).toInt() + 1;
         if (balls % 6 == 0) {
             currentInnings['overs'] = (balls / 6).toDouble();
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
      bool isAllOut = currentInnings['wickets'] >= 10;
      bool isOversCompleted = currentInnings['overs'] >= updatedMatch['totalOvers'];
      bool targetChased = updatedMatch['score']['target'] != null && currentInnings['runs'] >= updatedMatch['score']['target'];

      if (isAllOut || isOversCompleted || targetChased) {
          if (updatedMatch['score']['target'] == null) {
              updatedMatch['score']['target'] = (currentInnings['runs'] as int) + 1;
              String nextBatTeam = updatedMatch['score']['battingTeam'] == updatedMatch['teamA'] ? updatedMatch['teamB'] : updatedMatch['teamA'];
              // Auto switch or alert
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Innings Over! Target: ${updatedMatch['score']['target']}')));
              updatedMatch['score']['battingTeam'] = nextBatTeam;
              updatedMatch['score']['runs'] = 0; updatedMatch['score']['wickets'] = 0; updatedMatch['score']['overs'] = 0;
              updatedMatch['currentBatsmen'] = []; updatedMatch['currentBowler'] = null;
              Future.delayed(Duration(seconds: 1), () => _showStartDialog());
          } else {
              updatedMatch['status'] = 'completed';
              updatedMatch['manOfTheMatch'] = _calculateMOM(updatedMatch);
          }
      }
    }
    else if (type == 'new_batsman') {
        if (!battingSquad.contains(value)) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Player not in current batting team squad!'), backgroundColor: Colors.red));
           return;
        }
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
        if (!bowlingSquad.contains(value)) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Bowler not in bowling team squad!'), backgroundColor: Colors.red));
           return;
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
      var inn1 = m['innings'][0]; var inn2 = m['innings'][1];
      String? winner;
      if (inn1['runs'] > inn2['runs']) winner = inn1['team'];
      else if (inn2['runs'] > inn1['runs']) winner = inn2['team'];
      if (winner == null) return null;

      var winInn = m['innings'].firstWhere((i) => i['team'] == winner);
      var loseInn = m['innings'].firstWhere((i) => i['team'] != winner);

      Map<String, double> scores = {};
      (winInn['batting'] as List).forEach((p) => scores[p['player']] = (p['runs'] as num).toDouble());
      (winInn['bowling'] as List).forEach((p) => scores[p['player']] = (scores[p['player']] ?? 0) + (p['wickets'] as num) * 20); // Web used 25, I'll use 20 here or match web
      
      String? best; double max = -1;
      scores.forEach((name, s) { if (s > max) { max = s; best = name; } });
      return best;
    } catch (_) { return null; }
  }

  // --- UI COMPONENTS ---
  
  @override
  Widget build(BuildContext context) {
    bool isLive = match['status'] == 'live';
    bool isUpcoming = match['status'] == 'upcoming';

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('Admin Control Panel', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(
          icon: Icon(Icons.home),
          onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
        ),
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
                                    child: _actionButton('🚀 START 2ND INNINGS', successColor, Icons.play_arrow, _showStartDialog),
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
                            
                            // Additional Controls
                            SizedBox(height: 30),
                            _buildCorrectionPanel(isWide),
                            SizedBox(height: 15),
                            _buildAdvancedControls(isWide),
                            AppFooter(),
                            SizedBox(height: 40),
                          ],
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
              Text('QUICK ACTIONS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
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
                      label: Text('Change Bowler', style: TextStyle(color: Colors.teal)),
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

  Widget _buildCorrectionPanel(bool isWide) {
    bool isExpanded = false;
    return StatefulBuilder(builder: (context, setStateLocal) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Column(
          children: [
            ListTile(
              title: Text('🔧 CORRECTION PANEL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
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
                         var m = Map<String, dynamic>.from(match);
                         m['score']['runs'] = int.tryParse(v) ?? 0;
                         _handleUpdate('manual', m);
                      })),
                      SizedBox(width: 10),
                      Expanded(child: _miniInput('Wkts', match['score']['wickets'].toString(), (v) {
                         var m = Map<String, dynamic>.from(match);
                         m['score']['wickets'] = int.tryParse(v) ?? 0;
                         _handleUpdate('manual', m);
                      })),
                      SizedBox(width: 10),
                      Expanded(child: _miniInput('Overs', match['score']['overs'].toString(), (v) {
                         var m = Map<String, dynamic>.from(match);
                         m['score']['overs'] = double.tryParse(v) ?? 0.0;
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
                  _buildDropdown('Status', match['status'], ['upcoming', 'live', 'completed'], (v) {
                      var m = Map<String, dynamic>.from(match);
                      m['status'] = v;
                      _handleUpdate('manual', m);
                  }),
                ],
              ),
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
    int target = match['score']['target'] ?? 0;
    bool isSecondInnings = target > 0;
    
    double rrr = 0.0;
    int runsNeeded = 0;
    if (isSecondInnings) {
       runsNeeded = target - (match['score']['runs'] as int);
       int totalBalls = (match['totalOvers'] as int) * 6;
       double currentOvers = (match['score']['overs'] as num).toDouble();
       int ballsBowled = (currentOvers.floor() * 6) + ((currentOvers * 10) % 10).round();
       int ballsRemaining = totalBalls - ballsBowled;
       if (ballsRemaining > 0) rrr = (runsNeeded / ballsRemaining) * 6;
       else if (runsNeeded > 0) rrr = 99.9;
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(isWide ? 50 : 30), bottomRight: Radius.circular(isWide ? 50 : 30)),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 5))],
      ),
      padding: EdgeInsets.fromLTRB(20, isWide ? 30 : 10, 20, isWide ? 50 : 30),
      child: Column(
        children: [
          Text('${match['teamA'].toString().toUpperCase()} vs ${match['teamB'].toString().toUpperCase()}', style: TextStyle(color: Colors.white70, fontSize: isWide ? 20 : 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          SizedBox(height: 10),
          Text('${match['score']['runs']}/${match['score']['wickets']}', style: TextStyle(color: Colors.white, fontSize: isWide ? 80 : 56, fontWeight: FontWeight.w900)),
          Text('OVERS: ${match['score']['overs']} / ${match['totalOvers']}', style: TextStyle(color: warningColor, fontSize: isWide ? 24 : 18, fontWeight: FontWeight.bold)),
          if (isSecondInnings) ...[
             SizedBox(height: 10),
             Text('NEEDS $runsNeeded RUNS FROM ${((match['totalOvers'] * 6) - ((match['score']['overs'].floor() * 6) + ((match['score']['overs'] * 10) % 10).round())).toInt()} BALLS', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          ],
          SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
                child: Text('CRR: ${(match['score']['overs'] > 0 ? (match['score']['runs'] / (match['score']['overs'].floor() + (match['score']['overs'] % 1) * 1.666)).toStringAsFixed(2) : "0.00")}', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: isWide ? 16 : 14)),
              ),
              if (isSecondInnings) ...[
                SizedBox(width: 10),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: Colors.amber.withOpacity(0.3), borderRadius: BorderRadius.circular(20)),
                  child: Text('RRR: ${rrr.toStringAsFixed(2)}', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: isWide ? 16 : 14)),
                ),
              ]
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
                      Text(_lastBoundary.toString(), style: TextStyle(fontSize: 120, fontWeight: FontWeight.w900, color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 20)])),
                      Text(_lastBoundary == 6 ? 'MASSIVE SIX!' : 'FANTASTIC FOUR!', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2, shadows: [Shadow(color: Colors.black, blurRadius: 10)])),
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
    if (currentInnings == null || currentInnings['fow'] == null || (currentInnings['fow'] as List).isEmpty) return SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('FALL OF WICKETS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
        SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: (currentInnings['fow'] as List).map((f) => Container(
              margin: EdgeInsets.only(right: 10),
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade300)),
              child: Text('${f['wicket']}-${f['runs']} (${f['player']})', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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
                 Text('MATCH COMPLETED', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
                 SizedBox(height: 8),
                 Text(winnerMsg ?? 'MATCH DRAWN', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900), textAlign: TextAlign.center),
                 if (match['manOfTheMatch'] != null) ...[
                    SizedBox(height: 10),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
                      child: Text('🏅 MOM: ${match['manOfTheMatch']}', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    )
                 ]
               ],
             ),
           ),
           SizedBox(height: 20),
        ] else if (match['toss'] == null || match['toss']['winner'] == null)
           _actionButton('🪙 CONDUCT TOSS', warningColor, Icons.monetization_on, _showTossDialog, textColor: Colors.black)
        else if (match['toss'] != null && match['toss']['winner'] != null) ...[
           Container(
             padding: EdgeInsets.all(12),
             decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.amber)),
             child: Row(children: [Icon(Icons.info, color: Colors.amber[800]), SizedBox(width: 10), Expanded(child: Text('Toss won by ${match['toss']['winner']} elected to ${match['toss']['decision']}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber[900])))]),
           ),
           SizedBox(height: 15),
           _actionButton('🚀 START MATCH', successColor, Icons.play_arrow, _showStartDialog),
        ]
      ],
    );
  }

  String _calculateWinnerMsg(Map<String, dynamic> m) {
    try {
      if (m['innings'] == null || (m['innings'] as List).length < 2) return "MATCH COMPLETED";
      var inn1 = m['innings'][0]; var inn2 = m['innings'][1];
      int r1 = (inn1['runs'] ?? 0) as int;
      int r2 = (inn2['runs'] ?? 0) as int;
      
      if (r1 > r2) return "${inn1['team'].toString().toUpperCase()} WON BY ${r1 - r2} RUNS";
      if (r2 > r1) {
        int wkts = 10 - ((inn2['wickets'] ?? 0) as num).toInt();
        return "${inn2['team'].toString().toUpperCase()} WON BY $wkts WICKETS";
      }
      return "MATCH TIED";
    } catch (_) { return "MATCH COMPLETED"; }
  }
  
  Widget _buildLiveStatus(bool isWide) {
     List<dynamic> batsmen = match['currentBatsmen'] ?? [];
     String bowler = match['currentBowler'] ?? '-';
     
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
                   Text('BATTING', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                   SizedBox(height: 10),
                    ...batsmen.map((b) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text(b['name'].isEmpty ? '(Waiting...)' : b['name'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: isWide ? 16 : 14, color: b['onStrike'] ? primaryColor : Colors.black54), overflow: TextOverflow.ellipsis)),
                          Text(b['name'].isEmpty ? '' : '${b['runs']}(${b['balls']})', style: TextStyle(fontWeight: FontWeight.bold, fontSize: isWide ? 16 : 14)),
                        ],
                      ),
                    )),
                    if (batsmen.isNotEmpty && batsmen.any((b) => b['name'].isNotEmpty))
                      Divider(),
                    if (batsmen.length == 2 && batsmen.every((b) => b['name'].isNotEmpty))
                      Center(
                        child: TextButton.icon(
                          onPressed: () => _handleUpdate('swap_strike', null),
                          icon: Icon(Icons.swap_horiz, size: 16),
                          label: Text('Swap Strike', style: TextStyle(fontSize: 10)),
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
                   Text('BOWLING', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                   SizedBox(height: 10),
                   Text(bowler, style: TextStyle(fontSize: isWide ? 20 : 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                   SizedBox(height: 8),
                   Text('Active Over', style: TextStyle(fontSize: 12, color: Colors.grey)),
                 ],
               ),
             ),
           ),
         ),
       ],
     );
  }

  Widget _buildScoringGrid(bool isWide) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
             Expanded(child: _actionButton('SQUADS', Colors.blueGrey, Icons.group, () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => SquadScreen(match: match))); setState(() {}); }, isSmall: true)),
             SizedBox(width: 8),
             Expanded(child: _actionButton('BOWLER', Colors.teal, Icons.refresh, _showNewBowlerDialog, isSmall: true)),
             SizedBox(width: 8),
             Expanded(child: _actionButton('RETIRE B', Colors.deepOrange, Icons.person_off, () {
                _showSnackBar('Bowler retired manually');
                _showNewBowlerDialog();
             }, isSmall: true)),
          ],
        ),
        SizedBox(height: 20),
        GridView.count(
          physics: NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          crossAxisCount: isWide ? 5 : 3,
          mainAxisSpacing: isWide ? 20 : 12,
          crossAxisSpacing: isWide ? 20 : 12,
          childAspectRatio: isWide ? 1.5 : 1.3,
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
            _scoreTile('RET', Colors.info.shade50, () {
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
      borderRadius: BorderRadius.circular(15),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 4, offset: Offset(0, 2))],
          border: Border.all(color: Colors.grey.shade300, width: 1)
        ),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(fontSize: 24, fontWeight: isBold ? FontWeight.w900 : FontWeight.bold, color: textColor)),
      ),
    );
  }

  Widget _actionButton(String label, Color color, IconData icon, VoidCallback onTap, {Color textColor = Colors.white, bool isSmall = false}) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: textColor,
        minimumSize: Size(double.infinity, isSmall ? 45 : 55),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isSmall ? 10 : 15)),
        elevation: 3,
      ),
      icon: Icon(icon, size: isSmall ? 18 : 24),
      label: Text(label, style: TextStyle(fontSize: isSmall ? 14 : 16, fontWeight: FontWeight.bold)),
      onPressed: onTap,
    );
  }

  void _showTossDialog() {
    String winner = match['teamA'];
    String decision = 'bat';
    showDialog(context: context, builder: (context) {
       return StatefulBuilder(builder: (context, setState) {
         return AlertDialog(
           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
           title: Text('🪙 Coin Toss', style: TextStyle(fontWeight: FontWeight.bold)),
           content: Column(
             mainAxisSize: MainAxisSize.min,
             children: [
               _buildDropdown('Winner', winner, [match['teamA'], match['teamB']], (v) => setState(() => winner = v)),
               SizedBox(height: 15),
               _buildDropdown('Decision', decision, ['bat', 'bowl'], (v) => setState(() => decision = v)),
             ],
           ),
           actions: [
             TextButton(child: Text('Cancel', style: TextStyle(color: Colors.grey)), onPressed: () => Navigator.pop(context)),
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
    
    if (batsList.isEmpty || bowlList.isEmpty) {
      _showSnackBar('Squads are empty! Add 11 players per team in squads first.', isError: true);
      return;
    }

    String s = batsList.isNotEmpty ? batsList[0] : '';
    String ns = batsList.length > 1 ? batsList[1] : '';
    String b = bowlList.isNotEmpty ? bowlList[0] : '';
    
    showDialog(context: context, builder: (context) {
      return StatefulBuilder(builder: (context, setState) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('🚀 Start Match', style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor)),
          content: SingleChildScrollView(
            child: Column(
               mainAxisSize: MainAxisSize.min,
               children: [
                 Text('Set the initial players for the game.', style: TextStyle(color: Colors.grey, fontSize: 12)),
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

    showDialog(context: context, builder: (context) {
       return StatefulBuilder(builder: (context, setState) {
         return AlertDialog(
           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
           title: Text('☝️ Wicket Details', style: TextStyle(fontWeight: FontWeight.bold, color: dangerColor)),
           content: SingleChildScrollView(
             child: Column(
               mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDropdown('Dismissal Type', type.toUpperCase(), ['BOWLED', 'CAUGHT', 'RUN OUT', 'LBW', 'STUMPED', 'HIT WICKET', 'RETIRED HURT'], (v) => setState(() => type = v.toLowerCase())),
                 SizedBox(height: 15),
                 if (['caught', 'run out', 'stumped'].contains(type.toLowerCase()))
                    _buildDropdown('Fielder', fielder.isEmpty && fieldSquad.isNotEmpty ? (fielder = fieldSquad[0]) : fielder, fieldSquad, (v) => setState(() => fielder = v)),
                 
                 if (type.toLowerCase() == 'run out') ...[
                    SizedBox(height: 15),
                    _buildDropdown('Who is Out?', whoOut, [strikerName, nonStrikerName].where((n) => n.isNotEmpty).toList(), (v) => setState(() => whoOut = v)),
                    SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Batters Crossed?', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        Switch(value: crossed, activeColor: primaryColor, onChanged: (v) => setState(() => crossed = v)),
                      ],
                    ),
                    _buildDropdown('Runs Completed', runsCompleted.toString(), ['0', '1', '2', '3'], (v) => setState(() => runsCompleted = int.parse(v))),
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
                  'runs': runsCompleted
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
        
        // Players who haven't come to bat yet
        List<dynamic> availableBatsmen = squad.where((p) => !alreadyBatted.contains(p)).toList();
        
        if (availableBatsmen.isEmpty) {
          _showSnackBar('No more batsmen available in the squad!', isError: true);
          return;
        }

        String nextBat = availableBatsmen[0];
        
        showDialog(context: context, barrierDismissible: false, builder: (context) {
           return StatefulBuilder(builder: (context, setState) {
              return AlertDialog(
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                 title: Text('🏏 New Batsman', style: TextStyle(fontWeight: FontWeight.bold)),
                 content: Column(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                     Text('Select the next player from ${battingTeam}\'s squad.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                     SizedBox(height: 15),
                     _buildDropdown('Select Player', nextBat, availableBatsmen, (v) => setState(()=> nextBat = v)),
                   ],
                 ),
                  actions: [
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

  void _showNewBowlerDialog() {
      String battingTeam = match['score']['battingTeam'];
      String bowlingTeam = battingTeam == match['teamA'] ? match['teamB'] : match['teamA'];
      String currentBowler = match['currentBowler'] ?? '';
      List<dynamic> bowlList = match[bowlingTeam == match['teamA'] ? 'teamASquad' : 'teamBSquad'] ?? [];
      
      // Filter out current bowler if it's the start of a new over
      // (In cricket, a bowler cannot bowl two overs in a row)
      List<dynamic> filteredBowlList = bowlList.where((p) => p != currentBowler).toList();
      if (filteredBowlList.isEmpty) filteredBowlList = bowlList; // Fallback if squad is too small

      String nextBowl = filteredBowlList.isNotEmpty ? filteredBowlList[0] : '';
      
      showDialog(context: context, builder: (context) {
         return StatefulBuilder(builder: (context, setState) {
            return AlertDialog(
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
               title: Text('⚾ New Bowler', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
               content: Column(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   Text('Select which player will bowl the next over.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                   SizedBox(height: 15),
                   _buildDropdown('Select Bowler', nextBowl, filteredBowlList, (v) => setState(()=> nextBowl = v)),
                 ],
               ),
               actions: [
                 TextButton(child: Text('Cancel'), onPressed: () => Navigator.pop(context)),
                 ElevatedButton(
                   child: Text('START OVER'), 
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
           Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
           DropdownButtonHideUnderline(
             child: DropdownButton<String>(
               value: (items.contains(value)) ? value : null,
               hint: Text('Select...'),
               isExpanded: true,
               icon: Icon(Icons.arrow_drop_down_circle, color: primaryColor),
               items: items.map<DropdownMenuItem<String>>((v) => DropdownMenuItem(value: v.toString(), child: Text(v.toString(), style: TextStyle(fontWeight: FontWeight.bold)))).toList(),
               onChanged: (v) => onChanged(v!),
             ),
           ),
         ],
       ),
     );
  }
}
