import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../services/api_service.dart';
import '../providers/settings_provider.dart';
import 'profile_screen.dart';
import 'scorecard_screen.dart';
import '../widgets/app_footer.dart';
import '../widgets/app_drawer.dart';
import 'package:google_fonts/google_fonts.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> matches = [];
  bool isLoading = true;
  String? errorMessage;
  late IO.Socket socket;

  int _blastValue = 0;
  String? _blastMatchId;

  @override
  void initState() {
    super.initState();
    fetchMatches();
    initSocket();
  }

  void initSocket() {
    String socketUrl = ApiService.baseUrl.replaceAll('/api', '');
    socket = IO.io(socketUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });
    socket.connect();
    socket.on('matchUpdate', (data) {
      if (mounted && data != null && data is Map) {
        setState(() {
          int index = matches.indexWhere((m) {
            if (m == null || m is! Map) return false;
            return m['_id'] == data['_id'] || m['id'] == data['id'];
          });
          if (index != -1) {
            int oldRuns = 0;
            try { oldRuns = matches[index]['score']?['runs'] ?? 0; } catch(_) {}
            int newRuns = 0;
            try { newRuns = data['score']?['runs'] ?? 0; } catch(_) {}
            int diff = (newRuns - oldRuns).abs(); 
            if ((diff == 4 || diff == 6) && data['status'] == 'live') {
               _blastValue = diff;
               _blastMatchId = data['_id']?.toString() ?? data['id']?.toString();
               Future.delayed(Duration(seconds: 3), () {
                  if (mounted) setState(() => _blastMatchId = null);
               });
            }
            matches[index] = data;
          } else {
            matches.insert(0, data);
          }
        });
      }
    });
    socket.on('matchDeleted', (data) {
      if (mounted && data != null) {
        setState(() => matches.removeWhere((m) {
          if (m == null || m is! Map) return false;
          return m['_id'] == data || m['id'] == data;
        }));
      }
    });
  }

  @override
  void dispose() {
    socket.disconnect();
    socket.dispose();
    super.dispose();
  }

  Future<void> fetchMatches() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final data = await ApiService.getMatches();
      if (mounted) {
        setState(() {
          if (data is List) {
            matches = data;
          } else {
            errorMessage = 'Invalid data received from server';
            matches = [];
          }
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = e.toString().contains('TimeoutException') 
            ? 'Server is taking too long to respond. It might be waking up.' 
            : 'Error: ${e.toString().replaceAll('Exception:', '').trim()}';
          matches = []; // Ensure matches is empty on error
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final primaryBlue = Color(0xFF2563EB);
    
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        toolbarHeight: 70,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SMCC LIVE', 
              style: GoogleFonts.outfit(
                color: primaryBlue, 
                fontWeight: FontWeight.w900, 
                fontSize: 22, 
                letterSpacing: 1.2
              )
            ),
            Row(
              children: [
                _PulsingDot(),
                SizedBox(width: 8),
                Text('REAL-TIME CRICKET INTELLIGENCE', 
                  style: GoogleFonts.outfit(
                    color: Colors.grey, 
                    fontSize: 8, 
                    fontWeight: FontWeight.w900, 
                    letterSpacing: 1.5
                  )
                ),
              ],
            ),
          ],
        ),
        actions: const [
          SizedBox(width: 8),
        ],
      ),
      drawer: AppDrawer(),
      body: RefreshIndicator(
        onRefresh: fetchMatches,
        color: primaryBlue,
        child: _buildBody(settings, primaryBlue),
      ),
    );
  }

  Widget _buildBody(SettingsProvider settings, Color primaryBlue) {
    try {
      if (isLoading) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: primaryBlue),
              SizedBox(height: 24),
              Text('Loading...', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.grey)),
            ],
          ),
        );
      }

      if (errorMessage != null) {
        return ListView(
          children: [
            Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_off_rounded, size: 64, color: Colors.red.withOpacity(0.5)),
                  SizedBox(height: 24),
                  Text(errorMessage!, textAlign: TextAlign.center, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.red.shade900)),
                  SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: fetchMatches,
                    style: ElevatedButton.styleFrom(backgroundColor: primaryBlue, foregroundColor: Colors.white, shape: StadiumBorder()),
                    child: Text('RETRY CONNECTION', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12)),
                  )
                ],
              ),
            )
          ],
        );
      }

      if (matches.isEmpty) {
        return ListView(
          children: [
            Container(
              height: MediaQuery.of(context).size.height * 0.7,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.sports_cricket_rounded, size: 80, color: Colors.grey.withOpacity(0.2)),
                  SizedBox(height: 24),
                  Text('NO MATCHES SCHEDULED', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 2)),
                  TextButton(onPressed: fetchMatches, child: Text('TAP TO REFRESH', style: GoogleFonts.outfit(color: primaryBlue, fontWeight: FontWeight.bold))),
                ],
              ),
            )
          ],
        );
      }

      return SingleChildScrollView(
        padding: EdgeInsets.all(20),
        physics: AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  Hero(tag: 'logo', child: Image.asset('assets/logo.png', height: 80)),
                  SizedBox(height: 16),
                  Text('SMCC LIVE', style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w900, color: primaryBlue)),
                  Text('Real-time Cricket Intelligence', style: GoogleFonts.outfit(color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                ],
              ),
            ),
            SizedBox(height: 48),

            // LIVE SECTION - Added null checks to filter
            _buildSection('Live Matches', Colors.red, matches.where((m) => 
               m != null && m is Map && (m['status'] == 'live' || (m['status'] == 'upcoming' && m['toss'] != null && m['toss']['winner'] != null))
            ).toList(), settings, showMOM: false),
            
            // COMPLETED SECTION
            _buildSection('Recently Completed', Colors.green, matches.where((m) => 
               m != null && m is Map && m['status'] == 'completed'
            ).toList(), settings, showMOM: false),

            // UPCOMING SECTION
            _buildSection('Scheduled Matches', primaryBlue, matches.where((m) => 
               m != null && m is Map && m['status'] == 'upcoming' && (m['toss'] == null || m['toss']['winner'] == null)
            ).toList(), settings),

            SizedBox(height: 40),
            AppFooter(),
          ],
        ),
      );
    } catch (e) {
       return Center(
         child: Padding(
           padding: const EdgeInsets.all(32.0),
           child: Column(
             mainAxisAlignment: MainAxisAlignment.center,
             children: [
               Icon(Icons.terminal_rounded, size: 48, color: Colors.grey),
               SizedBox(height: 16),
               Text('Oops! Error during rendering.', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
               SizedBox(height: 8),
               Text(e.toString(), style: TextStyle(fontSize: 10, color: Colors.grey), textAlign: TextAlign.center),
               TextButton(onPressed: fetchMatches, child: Text('RELOAD'))
             ],
           ),
         ),
       );
    }
  }

  Widget _buildSection(String title, Color themeColor, List<dynamic> sectionMatches, SettingsProvider settings, {bool showMOM = false}) {
    if (sectionMatches.isEmpty) return SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(color: themeColor, borderRadius: BorderRadius.circular(8)),
              child: Icon(
                title.contains('Live') ? Icons.sensors_rounded : (title.contains('Completed') ? Icons.emoji_events_rounded : Icons.calendar_month_rounded),
                size: 20, color: Colors.white
              ),
            ),
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title.toUpperCase(), style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, color: themeColor, letterSpacing: 1.2)),
                if (title.contains('Completed')) Text('Final results and highlights', style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                if (title.contains('Scheduled')) Text('Gear up for upcoming action', style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
        SizedBox(height: 24),
        ..._buildGroupedMatches(sectionMatches, settings, showMOM: showMOM),
        SizedBox(height: 48),
      ],
    );
  }

  List<Widget> _buildGroupedMatches(List<dynamic> list, SettingsProvider settings, {bool showMOM = false}) {
    Map<String, List<dynamic>> groups = {};
    for (var m in list) {
      if (m == null || m is! Map) continue;
      String date = m['date']?.toString().split('T')[0] ?? 'TBD';
      if (!groups.containsKey(date)) groups[date] = [];
      groups[date]!.add(m);
    }

    List<Widget> result = [];
    groups.forEach((date, matches) {
      result.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(color: Color(0xFF2563EB).withOpacity(0.1), borderRadius: BorderRadius.circular(100)),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 12, color: Color(0xFF2563EB)),
                    SizedBox(width: 8),
                    Text(_formatDisplayDate(date), style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF2563EB))),
                  ],
                ),
              ),
              Expanded(child: Container(margin: EdgeInsets.only(left: 12), height: 1, color: Colors.grey.withOpacity(0.1))),
            ],
          ),
        )
      );
      
      for (var m in matches) {
        result.add(_buildMatchCard(m, settings, showMOM: showMOM));
        result.add(SizedBox(height: 16));
      }
    });

    return result;
  }

  String _formatDisplayDate(String dateStr) {
    try {
      if (dateStr == 'TBD') return 'TBD';
      DateTime dt = DateTime.parse(dateStr).toLocal();
      List<String> months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
      List<String> days = ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'];
      return "${days[dt.weekday - 1]}, ${dt.day} ${months[dt.month - 1]} ${dt.year}";
    } catch (_) { return dateStr; }
  }

  Widget _buildMatchCard(dynamic match, SettingsProvider settings, {bool showMOM = false}) {
    if (match == null || match is! Map) return SizedBox.shrink();
    bool isLive = match['status'] == 'live';
    String matchId = match['_id']?.toString() ?? match['id']?.toString() ?? 'unknown';
    Color primaryBlue = Color(0xFF2563EB);

    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ScorecardScreen(match: match))),
      borderRadius: BorderRadius.circular(24),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: Colors.grey.withOpacity(0.1))),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(match['title']?.toString().toUpperCase() ?? 'SMCC MATCH', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1))),
                      if (isLive) 
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red, 
                            borderRadius: BorderRadius.circular(100),
                            boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 8)]
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.broadcast_on_home_rounded, color: Colors.white, size: 10),
                              SizedBox(width: 4),
                              Text('LIVE', style: GoogleFonts.outfit(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
                            ],
                          ),
                        ),
                      if (match['status'] == 'upcoming')
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(color: primaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(100)),
                          child: Text('UPCOMING', style: GoogleFonts.outfit(color: primaryBlue, fontSize: 9, fontWeight: FontWeight.w900)),
                        ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_on_rounded, size: 12, color: Colors.red),
                      SizedBox(width: 4),
                      Text(match['venue']?.toString().toUpperCase() ?? 'TBD', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey.shade700)),
                    ],
                  ),
                  SizedBox(height: 32),
                  Row(
                    children: [
                      _buildTeamColumn(match['teamA'], match, primaryBlue),
                      _buildVSLabel(),
                      _buildTeamColumn(match['teamB'], match, primaryBlue),
                    ],
                  ),
                  SizedBox(height: 32),
                  _buildMatchBottomStatus(match, primaryBlue, settings, showMOM: showMOM),
                ],
              ),
            ),
            if (_blastMatchId == matchId) 
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: _buildBlastOverlay(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamColumn(dynamic name, dynamic match, Color primaryBlue) {
    if (match == null || match['score'] == null) return Expanded(child: SizedBox.shrink());
    
    bool isBatting = match['status'] == 'live' && match['score']?['battingTeam'] == name;
    
    dynamic innings;
    if (match['innings'] is List) {
       innings = (match['innings'] as List).firstWhere((inn) => inn != null && inn['team'] == name, orElse: () => null);
    }
    
    String score = "-";
    String overs = "-";
    
    if (innings != null) {
      score = "${innings['runs'] ?? 0}/${innings['wickets'] ?? 0}";
      overs = "(${innings['overs'] ?? 0} ov)";
    } else if (isBatting) {
      score = "${match['score']['runs'] ?? 0}/${match['score']['wickets'] ?? 0}";
      overs = "(${match['score']['overs'] ?? 0} ov)";
    }

    return Expanded(
      child: Column(
        children: [
          FittedBox(fit: BoxFit.scaleDown, child: Text(name?.toString().toUpperCase() ?? 'TEAM', textAlign: TextAlign.center, style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14))),
          SizedBox(height: 12),
          FittedBox(fit: BoxFit.scaleDown, child: Text(score, style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, color: primaryBlue))),
          Text(overs, style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildVSLabel() {
    return Container(
      width: 32, height: 32,
      decoration: BoxDecoration(color: Color(0xFF2563EB).withOpacity(0.1), shape: BoxShape.circle),
      child: Center(child: Text('VS', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF2563EB)))),
    );
  }

  Widget _buildMatchBottomStatus(dynamic match, Color primaryBlue, SettingsProvider settings, {bool showMOM = false}) {
    if (match['status'] == 'completed') {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.green.withOpacity(0.2))),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.emoji_events_rounded, color: Colors.green, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(_calculateWinnerInfo(match).toUpperCase(), style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.green.shade900)),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (match['status'] == 'live') {
      bool isSuperOver = (match['innings'] as List?)?.length != null && (match['innings'] as List).length > 2;
      return Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: primaryBlue.withOpacity(0.05), 
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: primaryBlue.withOpacity(0.1))
        ),
        child: Column(
          children: [
            if (isSuperOver)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text('MATCH TIED | SUPER OVER IN PROGRESS', 
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.orange.shade900, fontSize: 11)),
              ),
            if (match['score'] != null && match['score'] is Map && match['score']['target'] != null) ...[
              Text(_calculateRequiredText(match), style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.red.shade700, fontSize: 13)),
              SizedBox(height: 4),
              Text(_calculateRRR(match), style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey.shade600)),
              Divider(height: 24, thickness: 1, color: primaryBlue.withOpacity(0.1)),
            ],
            if (match['currentBatsmen'] != null && match['currentBatsmen'] is List && (match['currentBatsmen'] as List).isNotEmpty)
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: (match['currentBatsmen'] as List).where((b) => b != null && b is Map).map((b) => Row(
                            children: [
                              Text(b['onStrike'] == true ? "🏏 " : "   ", style: TextStyle(fontSize: 14)),
                              Text(
                                '${b['name'] ?? 'Batter'}${b['onStrike'] == true ? '*' : ''}: ',
                                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: b['onStrike'] == true ? Colors.black : Colors.grey.shade700),
                              ),
                              Text(
                                '${b['runs'] ?? 0}(${b['balls'] ?? 0})',
                                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: b['onStrike'] == true ? primaryBlue : Colors.grey.shade700),
                              ),
                            ],
                          )).toList(),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('⚾ ${match['currentBowler'] ?? "..."}', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900)),
                          SizedBox(height: 4),
                          _buildThisOver(match['score']?['thisOver'] is List ? match['score']['thisOver'] : []),
                        ],
                      ),
                    ],
                  ),
                ],
              )
            else
              Text('☕ INNINGS BREAK', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.orange, letterSpacing: 2)),
          ],
        ),
      );
    }

    if (match['toss'] != null && match['toss']['winner'] != null) {
      return Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.toll_rounded, color: Colors.orange, size: 16),
            SizedBox(width: 8),
            Text('TOSS: ${match['toss']['winner'].toUpperCase()} WON & ELECTED TO ${match['toss']['decision'].toUpperCase()}', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.orange.shade900)),
          ],
        ),
      );
    }

    return SizedBox.shrink();
  }

  String _calculateRequiredText(dynamic match) {
    try {
      num target = match['score']['target'];
      num runs = match['score']['runs'] ?? 0;
      int totalOvers = (match['innings'] as List?)?.length != null && (match['innings'] as List).length > 2 ? 1 : (match['totalOvers'] ?? 20);
      int totalBalls = totalOvers * 6;
      num overs = match['score']['overs'] ?? 0;
      int ballsBowled = (overs.floor() * 6) + ((overs * 10) % 10).round().toInt();
      int ballsRemaining = totalBalls - ballsBowled;
      num runsNeeded = target - runs;
      
      if (runsNeeded <= 0) return "SCORES LEVEL";
      return "${match['score']['battingTeam'].toString().toUpperCase()} NEEDS $runsNeeded RUNS FROM $ballsRemaining BALLS";
    } catch (_) { return "TARGET: ${match['score']['target']}"; }
  }

  Widget _buildThisOver(List<dynamic>? thisOver) {
    if (thisOver == null) return SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: thisOver.map((ball) {
        if (ball == null) return SizedBox.shrink();
        String ballStr = ball.toString().toUpperCase();
        bool isSix = ballStr == '6';
        bool isFour = ballStr == '4';
        bool isWicket = ballStr == 'W' || ballStr == 'OUT';
        bool isExtra = ballStr.contains('WD') || ballStr.contains('NB');

        Color bg = Colors.white;
        Color text = Colors.black;
        if (isSix) { bg = Color(0xFF2563EB); text = Colors.white; }
        else if (isFour) { bg = Colors.green; text = Colors.white; }
        else if (isWicket) { bg = Colors.red; text = Colors.white; }
        else if (isExtra) { bg = Colors.orange; text = Colors.white; }

        return Container(
          margin: EdgeInsets.only(left: 4),
          width: 18, height: 18,
          decoration: BoxDecoration(
            color: bg, 
            shape: BoxShape.circle, 
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
            boxShadow: (isSix || isFour) ? [BoxShadow(color: bg.withOpacity(0.4), blurRadius: 4)] : []
          ),
          child: Center(child: Text(ballStr, style: GoogleFonts.outfit(fontSize: 7, fontWeight: FontWeight.w900, color: text))),
        );
      }).toList(),
    );
  }

  String _calculateRRR(dynamic match) {
    try {
      if (match == null || match['score'] == null) return "";
      num target = match['score']['target'] ?? 0;
      num runs = match['score']['runs'] ?? 0;
      num overs = match['score']['overs'] ?? 0;
      int inningsCount = (match['innings'] is List) ? (match['innings'] as List).length : 0;
      int totalOvers = inningsCount > 2 ? 1 : (match['totalOvers'] ?? 20);
      int totalBalls = totalOvers * 6;
      int ballsBowled = (overs.floor() * 6) + ((overs * 10) % 10).round().toInt();
      int ballsRemaining = totalBalls - ballsBowled;
      num runsNeeded = target - runs;
      if (runsNeeded <= 0) return "TARGET REACHED";
      if (ballsRemaining <= 0) return "INNINGS OVER";
      double rrr = (runsNeeded / ballsRemaining) * 6;
      return "RRR: ${rrr.toStringAsFixed(2)}";
    } catch (_) { return ""; }
  }

  Widget _buildBlastOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              duration: Duration(milliseconds: 500),
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, _) => Transform.scale(
                scale: 0.5 + (value * 1.0),
                child: Opacity(
                  opacity: value,
                  child: Text(_blastValue.toString(), style: GoogleFonts.outfit(fontSize: 80, fontWeight: FontWeight.w900, color: _blastValue == 6 ? Colors.green : Colors.orange)),
                ),
              ),
            ),
            Text(_blastValue == 6 ? 'SIX!' : 'FOUR!', style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 4)),
          ],
        ),
      ),
    );
  }

  String _calculateWinnerInfo(dynamic match) {
    try {
      if (match == null || match['innings'] == null) return "MATCH COMPLETED";
      List innings = match['innings'] is List ? match['innings'] : [];
      if (innings.length < 2) return "MATCH COMPLETED";
      
      dynamic inn1 = innings[0], inn2 = innings[1];
      if (innings.length >= 4) { 
        inn1 = innings[innings.length - 2]; 
        inn2 = innings[innings.length - 1]; 
      }

      if (inn1 == null || inn2 == null) return "MATCH COMPLETED";

      int r1 = (inn1['runs'] as num?)?.toInt() ?? 0;
      int r2 = (inn2['runs'] as num?)?.toInt() ?? 0;
      bool isSuperOver = innings.length > 2;

      if (r1 > r2) {
        if (isSuperOver) return "MATCH TIED | ${inn1['team'] ?? 'TEAM A'} WON VIA SUPER OVER";
        return "${inn1['team'] ?? 'TEAM A'} WON BY ${r1 - r2} RUNS";
      }
      if (r2 > r1) {
        if (isSuperOver) return "MATCH TIED | ${inn2['team'] ?? 'TEAM B'} WON VIA SUPER OVER";
        return "${inn2['team'] ?? 'TEAM B'} WON BY ${10 - (inn2['wickets'] ?? 10)} WICKETS";
      }
      return isSuperOver ? "MATCH DRAWN | SUPER OVER TIED" : "MATCH DRAWN";
    } catch (e) {
      return "MATCH COMPLETED";
    }
  }
}

class _PulsingDot extends StatefulWidget {
  @override
  __PulsingDotState createState() => __PulsingDotState();
}

class __PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() { super.initState(); _controller = AnimationController(vsync: this, duration: Duration(seconds: 1))..repeat(reverse: true); }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _controller, child: Container(width: 10, height: 10, decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.5), blurRadius: 8, spreadRadius: 2)])));
  }
}
