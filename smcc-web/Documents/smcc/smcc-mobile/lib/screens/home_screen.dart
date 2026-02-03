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

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> matches = [];
  bool isLoading = true;
  String? errorMessage;
  late IO.Socket socket;

  bool _showBlast = false;
  int _blastValue = 0;
  String _blastMatchTitle = "";

  @override
  void initState() {
    super.initState();
    fetchMatches();
    initSocket();
  }

  void initSocket() {
    socket = IO.io('https://smcc-backend.onrender.com', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });
    socket.connect();
    socket.on('matchUpdate', (data) {
      if (mounted) {
        setState(() {
          int index = matches.indexWhere((m) => m['_id'] == data['_id'] || m['id'] == data['id']);
          if (index != -1) {
            // Animation Check
            int oldRuns = matches[index]['score']?['runs'] ?? 0;
            int newRuns = data['score']?['runs'] ?? 0;
            int diff = newRuns - oldRuns;
            if ((diff == 4 || diff == 6) && data['status'] == 'live') {
               _blastValue = diff;
               _blastMatchTitle = data['title'] ?? "${data['teamA']} vs ${data['teamB']}";
               _showBlast = true;
               Future.delayed(Duration(seconds: 3), () {
                  if (mounted) setState(() => _showBlast = false);
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
      if (mounted) {
        setState(() {
          matches.removeWhere((m) => m['_id'] == data || m['id'] == data);
        });
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
          matches = data;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          if (e.toString().contains('TimeoutException')) {
            errorMessage = 'Server is taking too long to respond. It might be waking up.';
          } else {
            errorMessage = 'Failed to load matches. Please check your connection.';
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).cardColor,
        toolbarHeight: 80,
        title: Row(
          children: [
            Image.asset('assets/logo.png', height: 40),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SMCC LIVE', style: TextStyle(color: Colors.blue.shade800, fontWeight: FontWeight.w900, fontSize: 18)),
                  Text(settings.translate('live_scores'), style: TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(settings.isDarkMode ? Icons.light_mode : Icons.dark_mode, size: 20),
            onPressed: settings.toggleTheme,
          ),
          IconButton(
            icon: Icon(Icons.person, color: Colors.blue.shade800),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen()));
            },
            tooltip: 'Profile',
          ),
          SizedBox(width: 4),
        ],
      ),
      body: Stack(
        children: [
          _buildMainContent(settings),
          if (_showBlast) Positioned.fill(child: IgnorePointer(child: _buildBlastOverlay())),
        ],
      ),
    );
  }

  Widget _buildMainContent(SettingsProvider settings) {
     return isLoading 
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text('Fetching matches...', style: TextStyle(color: Colors.blue.shade800, fontWeight: FontWeight.bold)),
                  Text('The server may take a moment to wake up.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            )
          : errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cloud_off, size: 60, color: Colors.red.shade300),
                        SizedBox(height: 16),
                        Text(errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: Colors.red.shade800, fontWeight: FontWeight.bold)),
                        SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: fetchMatches,
                          icon: Icon(Icons.refresh),
                          label: Text('Retry'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade800, foregroundColor: Colors.white),
                        ),
                      ],
                    ),
                  ),
                )
              : LayoutBuilder(
              builder: (context, constraints) {
                if (matches.isEmpty) {
                  return Center(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.sports_cricket_outlined, size: 80, color: Colors.grey.shade300),
                      SizedBox(height: 16),
                      Text(settings.translate('no_matches'), style: TextStyle(color: Colors.grey, fontSize: 18, fontWeight: FontWeight.bold)),
                      SizedBox(height: 10),
                      TextButton(onPressed: fetchMatches, child: Text('Refresh'))
                    ],
                  ));
                }

                int crossAxisCount = constraints.maxWidth > 700 ? 2 : 1;

                return SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // LIVE Section
                      if (matches.any((m) => m['status'] == 'live')) ...[
                        _buildSectionHeader(settings.translate('live').toUpperCase(), Colors.red, Icons.circle, true),
                        ..._buildMatchesByDate(matches.where((m) => m['status'] == 'live').toList(), settings),
                        SizedBox(height: 30),
                      ],
                      
                      // COMPLETED Section
                      if (matches.any((m) => m['status'] == 'completed')) ...[
                        _buildSectionHeader(settings.translate('completed').toUpperCase(), Colors.green, Icons.emoji_events, false),
                        ..._buildMatchesByDate(matches.where((m) => m['status'] == 'completed').toList(), settings),
                        SizedBox(height: 30),
                      ],

                      // UPCOMING Section
                      if (matches.any((m) => m['status'] == 'upcoming')) ...[
                        _buildSectionHeader(settings.translate('upcoming').toUpperCase(), Colors.blue, Icons.calendar_today, false),
                        ..._buildMatchesByDate(matches.where((m) => m['status'] == 'upcoming').toList(), settings),
                        SizedBox(height: 30),
                      ],

                      if (matches.isEmpty) 
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 50.0),
                          child: Center(child: Text('No matches available', style: TextStyle(color: Colors.grey))),
                        ),
                      
                      AppFooter(),
                    ],
                  ),
                );
              },
            );
  }

  Widget _buildBlastOverlay() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 1000),
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, value, child) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
                  child: Text(_blastMatchTitle, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade800, fontSize: 12)),
                ),
                SizedBox(height: 20),
                Transform.scale(
                  scale: 0.5 + value * 1.5,
                  child: Opacity(
                    opacity: (1.0 - value).clamp(0.0, 1.0),
                    child: Text(_blastValue.toString(), style: TextStyle(fontSize: 150, fontWeight: FontWeight.w900, color: _blastValue == 6 ? Colors.green : Colors.orange, shadows: [Shadow(color: Colors.black, blurRadius: 20)])),
                  ),
                ),
                Text(_blastValue == 6 ? 'SIX!' : 'FOUR!', style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 5)),
              ],
            );
          }
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color, IconData icon, bool animate) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          SizedBox(width: 8),
          Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: color, letterSpacing: 1.2)),
          Spacer(),
          Container(height: 1, width: 40, color: color.withOpacity(0.2)),
        ],
      ),
    );
  }

  Widget _buildEmptySection(String message) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Center(
        child: Text(message, style: TextStyle(color: Colors.grey, fontSize: 11, fontStyle: FontStyle.italic)),
      ),
    );
  }

  List<Widget> _buildMatchesByDate(List<dynamic> filteredMatches, SettingsProvider settings) {
    if (filteredMatches.isEmpty) return [];

    Map<String, List<dynamic>> groups = {};
    for (var m in filteredMatches) {
      String date = m['date']?.toString().split('T')[0] ?? 'Unknown Date';
      if (!groups.containsKey(date)) groups[date] = [];
      groups[date]!.add(m);
    }

    List<Widget> widgets = [];
    groups.forEach((date, list) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border(left: BorderSide(color: Colors.blue.shade800, width: 4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_month, size: 12, color: Colors.blue.shade800),
                SizedBox(width: 8),
                Text(
                  _formatDateHeadline(date),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.blue.shade800, letterSpacing: 0.5),
                ),
              ],
            ),
          ),
        )
      );
      
      widgets.add(
        ListView.separated(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: list.length,
          separatorBuilder: (context, index) => SizedBox(height: 12),
          itemBuilder: (context, index) => ConstrainedBox(
            constraints: BoxConstraints(maxHeight: 250),
            child: _buildMatchCard(list[index], settings)
          ),
        )
      );
    });

    return widgets;
  }

  String _formatDateHeadline(String dateStr) {
    try {
      DateTime dt = DateTime.parse(dateStr);
      // Format: Monday, 02 February 2026
      return "${_getWeekday(dt.weekday)}, ${dt.day.toString().padLeft(2, '0')} ${_getMonthName(dt.month)} ${dt.year}";
    } catch (e) {
      return dateStr;
    }
  }

  String _getWeekday(int day) {
    return ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][day - 1];
  }

  String _getMonthName(int month) {
    return ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'][month - 1];
  }

  Widget _buildMatchCard(dynamic match, SettingsProvider settings) {
    bool isLive = match['status'] == 'live';
    return Card(
      elevation: 2,
      margin: EdgeInsets.all(0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: isLive ? Colors.red.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Expanded(child: Text(match['title'] ?? 'Match', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isLive ? Colors.red.shade900 : Colors.blue.shade900), overflow: TextOverflow.ellipsis)),
                  if (match['status'] != 'upcoming') 
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: isLive ? Colors.red : Colors.grey, borderRadius: BorderRadius.circular(20)),
                      child: Text(settings.translate(match['status']), style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),
            
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${match['date']?.toString().split('T')[0] ?? ''} | ${match['venue']}', style: TextStyle(color: Colors.grey, fontSize: 9)),
                    SizedBox(height: 5),
                    Row(
                      children: [
                        _buildTeamScore(match['teamA'], match, match['status'] == 'completed' || match['score']?['battingTeam'] == match['teamA'], settings),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2.0),
                          child: Text('VS', style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.bold, fontSize: 10)),
                        ),
                        _buildTeamScore(match['teamB'], match, match['status'] == 'completed' || match['score']?['battingTeam'] == match['teamB'], settings),
                      ],
                    ),
                    if (match['status'] == 'completed') 
                       Container(
                         width: double.infinity,
                         padding: EdgeInsets.all(8),
                         decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.green.shade100)),
                         child: Column(
                           children: [
                              Text(
                                _calculateWinnerInfo(match),
                                style: TextStyle(fontSize: 10, color: Colors.green.shade900, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                              if (match['manOfTheMatch'] != null) ...[
                                SizedBox(height: 4),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.green.shade200)),
                                  child: Text('🏅 MOM: ${match['manOfTheMatch'].toString().toUpperCase()}', style: TextStyle(fontSize: 8, color: Colors.green.shade700, fontWeight: FontWeight.bold)),
                                ),
                              ]
                           ],
                         ),
                       ),
                    if (match['toss'] != null && match['toss']['winner'] != null && match['status'] != 'completed')
                       Padding(
                         padding: const EdgeInsets.symmetric(vertical: 4.0),
                         child: Text(
                           'Toss: ${match['toss']['winner']} elected to ${match['toss']['decision']}',
                           style: TextStyle(fontSize: 8, color: Colors.orange.shade900, fontStyle: FontStyle.italic, fontWeight: FontWeight.bold),
                           textAlign: TextAlign.center,
                           maxLines: 1,
                           overflow: TextOverflow.ellipsis,
                         ),
                       ),
                    if (isLive) ...[
                      _buildLiveStats(match, settings),
                      if (match['score']?['target'] != null) ...[
                        SizedBox(height: 5),
                        _buildRRRDisplay(match, settings),
                      ]
                    ],
                    SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ScorecardScreen(match: match))),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Color(0xFF009270),
                        elevation: 0,
                        padding: EdgeInsets.symmetric(vertical: 0),
                        side: BorderSide(color: Color(0xFF009270)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        minimumSize: Size(double.infinity, 30),
                      ),
                      child: Text('${settings.translate('full_scorecard')} →', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRRRDisplay(dynamic match, SettingsProvider settings) {
    if (match['score']?['target'] == null) return SizedBox.shrink();

    int runsNeeded = (match['score']['target'] as int) - (match['score']['runs'] as int);
    int totalBalls = (match['totalOvers'] as int) * 6;
    double currentOvers = (match['score']['overs'] as num).toDouble();
    int ballsBowled = (currentOvers.floor() * 6) + ((currentOvers * 10) % 10).round();
    int ballsRemaining = totalBalls - ballsBowled;
    
    double rrr = 0.0;
    if (ballsRemaining > 0) {
       rrr = (runsNeeded / ballsRemaining) * 6;
    } else if (runsNeeded > 0) {
       rrr = 99.99;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(5), border: Border.all(color: Colors.orange.shade200)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Target: ${match['score']['target']}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange.shade800)),
          Text('RRR: ${rrr.toStringAsFixed(2)}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange.shade800)),
        ],
      ),
    );
  }

  Widget _buildLiveStats(dynamic match, SettingsProvider settings) {
    return Container(
      margin: EdgeInsets.only(top: 15),
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.grey.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(settings.translate('batting'), style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.grey)),
              Text(settings.translate('bowling'), style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.grey)),
            ],
          ),
          SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: (match['currentBatsmen'] as List? ?? []).map((b) => Text(
                    '${b['onStrike'] == true ? "🏏 " : ""}${b['name']}: ${b['runs']}(${b['balls']})',
                    style: TextStyle(fontSize: 10, fontWeight: b['onStrike'] == true ? FontWeight.bold : FontWeight.normal),
                  )).toList(),
                ),
              ),
              num.tryParse(match['currentBowler'].toString()) != null 
                ? SizedBox.shrink() 
                : Text('⚾ ${match['currentBowler'] ?? ''}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
          if (match['score']?['thisOver'] != null && (match['score']['thisOver'] as List).isNotEmpty) ...[
            SizedBox(height: 8),
            Divider(height: 1, thickness: 0.5),
            SizedBox(height: 8),
            Row(
              children: [
                Text('THIS OVER: ', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.grey)),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: (match['score']['thisOver'] as List).map((ball) => Container(
                        margin: EdgeInsets.symmetric(horizontal: 2),
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: ball.toString().contains('W') ? Colors.red.shade100 : (ball.toString().contains('nb') || ball.toString().contains('wd') ? Colors.orange.shade100 : Colors.blue.shade50),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(ball.toString(), style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: ball.toString().contains('W') ? Colors.red : Colors.black87)),
                      )).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTeamScore(String team, dynamic match, bool showScore, SettingsProvider settings) {
    dynamic innings = (match['innings'] as List?)?.firstWhere((inn) => inn['team'] == team, orElse: () => null);
    String runs = innings != null ? '${innings['runs']}/${innings['wickets']}' : (match['score']?['battingTeam'] == team ? '${match['score']['runs']}/${match['score']['wickets']}' : '-');
    String overs = innings != null ? '${innings['overs']} ${settings.translate('overs')}' : (match['score']?['battingTeam'] == team ? '${match['score']['overs']} ${settings.translate('overs')}' : '');

    return Expanded(
      child: Column(
        children: [
          Text(team.toUpperCase(), textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
          if (showScore && runs != '-') 
            Column(
              children: [
                Text(runs, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.blue.shade700)),
                Text(overs, style: TextStyle(fontSize: 9, color: Colors.grey)),
              ],
            )
          else
            Container(height: 35, alignment: Alignment.center, child: Text('-', style: TextStyle(color: Colors.grey.shade300))),
        ],
      ),
    );
  }

  String _calculateWinnerInfo(dynamic match) {
    if (match['innings'] == null || (match['innings'] as List).length < 2) return "MATCH COMPLETED";
    var inn1 = match['innings'][0];
    var inn2 = match['innings'][1];
    int r1 = (inn1['runs'] as num).toInt();
    int r2 = (inn2['runs'] as num).toInt();
    if (r1 > r2) return "${inn1['team'].toString().toUpperCase()} WON BY ${r1 - r2} RUNS";
    if (r2 > r1) return "${inn2['team'].toString().toUpperCase()} WON BY ${10 - (inn2['wickets'] as num).toInt()} WICKETS";
    return "MATCH DRAWN";
  }
}
