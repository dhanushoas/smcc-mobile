import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../services/api_service.dart';
import '../providers/settings_provider.dart';
import 'profile_screen.dart';
import 'scorecard_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> matches = [];
  bool isLoading = true;
  late IO.Socket socket;

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
    try {
      final data = await ApiService.getMatches();
      if (mounted) {
        setState(() {
          matches = data;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
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
          PopupMenuButton<String>(
            icon: Icon(Icons.language, size: 20),
            tooltip: 'Language',
            onSelected: (String lang) => settings.setLanguage(lang),
            itemBuilder: (context) => [
              PopupMenuItem(value: 'en', child: Text('🇺🇸 English')),
              PopupMenuItem(value: 'ta', child: Text('🇮🇳 தமிழ்')),
            ],
          ),
          IconButton(
            icon: Icon(Icons.account_circle, size: 28, color: Colors.blue.shade800),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen())).then((_) {
                 // Refresh state if needed when coming back
                 setState(() {}); 
              });
            },
            tooltip: 'Profile',
          ),
          SizedBox(width: 4),
        ],
      ),
      body: isLoading 
          ? Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                if (matches.isEmpty) {
                  return Center(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.sports_cricket_outlined, size: 80, color: Colors.grey.shade300),
                      SizedBox(height: 16),
                      Text(settings.translate('no_matches'), style: TextStyle(color: Colors.grey, fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ));
                }

                // Determine grid crossAxisCount based on screen width
                int crossAxisCount = constraints.maxWidth > 700 ? 2 : 1;

                return SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (matches.any((m) => m['status'] == 'live')) ...[
                         _buildSectionTitle(settings.translate('live').toUpperCase(), Colors.red),
                         GridView.count(
                           shrinkWrap: true,
                           physics: NeverScrollableScrollPhysics(),
                           crossAxisCount: crossAxisCount,
                           mainAxisSpacing: 10,
                           crossAxisSpacing: 10,
                           childAspectRatio: constraints.maxWidth > 700 ? 1.5 : 1.2,
                           children: matches.where((m) => m['status'] == 'live').map((m) => _buildMatchCard(m, settings)).toList(),
                         ),
                         SizedBox(height: 20),
                      ],
                      if (matches.any((m) => m['status'] == 'upcoming')) ...[
                         _buildSectionTitle(settings.translate('upcoming').toUpperCase(), Colors.blue),
                         GridView.count(
                           shrinkWrap: true,
                           physics: NeverScrollableScrollPhysics(),
                           crossAxisCount: crossAxisCount,
                           mainAxisSpacing: 10,
                           crossAxisSpacing: 10,
                           childAspectRatio: constraints.maxWidth > 700 ? 1.5 : 1.2,
                           children: matches.where((m) => m['status'] == 'upcoming').map((m) => _buildMatchCard(m, settings)).toList(),
                         ),
                         SizedBox(height: 20),
                      ],
                      if (matches.any((m) => m['status'] == 'completed')) ...[
                         _buildSectionTitle(settings.translate('completed').toUpperCase(), Colors.grey),
                         GridView.count(
                           shrinkWrap: true,
                           physics: NeverScrollableScrollPhysics(),
                           crossAxisCount: crossAxisCount,
                           mainAxisSpacing: 10,
                           crossAxisSpacing: 10,
                           childAspectRatio: constraints.maxWidth > 700 ? 1.5 : 1.2,
                           children: matches.where((m) => m['status'] == 'completed').map((m) => _buildMatchCard(m, settings)).toList(),
                         ),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildSectionTitle(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Row(
        children: [
          Container(width: 4, height: 16, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          SizedBox(width: 8),
          Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.grey.shade600, letterSpacing: 1.2)),
        ],
      ),
    );
  }

  Widget _buildMatchCard(dynamic match, SettingsProvider settings) {
    bool isLive = match['status'] == 'live';
    return Card(
      elevation: 2,
      margin: EdgeInsets.all(0), // Margin handled by GridView spacing
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
                    if (match['toss'] != null && match['toss']['winner'] != null)
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
       rrr = 99.99; // Infinite
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
              Text('⚾ ${match['currentBowler'] ?? ''}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
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
          Text(team, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
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
}
