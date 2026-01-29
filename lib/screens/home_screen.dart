import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../services/api_service.dart';
import '../providers/settings_provider.dart';
import 'login_screen.dart';
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
            onSelected: (String lang) => settings.setLanguage(lang),
            itemBuilder: (context) => [
              PopupMenuItem(value: 'en', child: Text('🇺🇸 English')),
              PopupMenuItem(value: 'ta', child: Text('🇮🇳 தமிழ்')),
            ],
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
                return ListView(
                  padding: EdgeInsets.all(16),
                  children: [
                    if (matches.any((m) => m['status'] == 'live')) ...[
                       _buildSectionTitle(settings.translate('live').toUpperCase(), Colors.red),
                       ...matches.where((m) => m['status'] == 'live').map((m) => _buildMatchCard(m, settings)),
                       SizedBox(height: 20),
                    ],
                    if (matches.any((m) => m['status'] == 'upcoming')) ...[
                       _buildSectionTitle(settings.translate('upcoming').toUpperCase(), Colors.blue),
                       ...matches.where((m) => m['status'] == 'upcoming').map((m) => _buildMatchCard(m, settings)),
                       SizedBox(height: 20),
                    ],
                    if (matches.any((m) => m['status'] == 'completed')) ...[
                       _buildSectionTitle(settings.translate('completed').toUpperCase(), Colors.grey),
                       ...matches.where((m) => m['status'] == 'completed').map((m) => _buildMatchCard(m, settings)),
                    ],
                  ],
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: isLive ? Colors.red.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(match['title'] ?? 'Match', style: TextStyle(fontWeight: FontWeight.bold, color: isLive ? Colors.red.shade900 : Colors.blue.shade900)),
                  if (match['status'] != 'upcoming') 
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: isLive ? Colors.red : Colors.grey, borderRadius: BorderRadius.circular(20)),
                      child: Text(settings.translate(match['status']), style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),
            
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text('${match['date']?.toString().split('T')[0] ?? ''} | ${match['venue']}', style: TextStyle(color: Colors.grey, fontSize: 10)),
                    SizedBox(height: 15),
                    Row(
                      children: [
                        _buildTeamScore(match['teamA'], match, match['status'] == 'completed' || match['score']?['battingTeam'] == match['teamA'], settings),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: Text('VS', style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                        _buildTeamScore(match['teamB'], match, match['status'] == 'completed' || match['score']?['battingTeam'] == match['teamB'], settings),
                      ],
                    ),
                    if (isLive) _buildLiveStats(match, settings),
                    Spacer(),
                    ElevatedButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ScorecardScreen(match: match))),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Color(0xFF009270),
                        elevation: 0,
                        side: BorderSide(color: Color(0xFF009270)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        minimumSize: Size(double.infinity, 36),
                      ),
                      child: Text('${settings.translate('full_scorecard')} →', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
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
