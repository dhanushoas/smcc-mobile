import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../widgets/app_footer.dart';

class ScorecardScreen extends StatefulWidget {
  final dynamic match;

  ScorecardScreen({required this.match});

  @override
  _ScorecardScreenState createState() => _ScorecardScreenState();
}

class _ScorecardScreenState extends State<ScorecardScreen> {
  int _activeTab = 0; // 0 for Scorecard, 1 for Match Info
  late dynamic match;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    match = widget.match;
    if (match['status'] == 'live') {
      _fetchMatchUpdate();
      _startPolling();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _timer = Timer.periodic(Duration(seconds: 5), (timer) => _fetchMatchUpdate());
  }

  Future<void> _fetchMatchUpdate() async {
    try {
      final updatedMatch = await ApiService.getMatch(match['_id'] ?? match['id']);
      if (mounted) {
        setState(() => match = updatedMatch);
        if (match['status'] != 'live') _timer?.cancel();
      }
    } catch (_) {}
  }


  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final primaryBlue = Color(0xFF2563EB);
    List<dynamic> inningsList = match['innings'] ?? [];
    bool isCompleted = ['completed', 'abandoned', 'cancelled'].contains(match['status']);
    
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation:0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: primaryBlue, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('MATCH ANALYTICS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: primaryBlue, fontSize: 16, letterSpacing: 1.2)),
        actions: [
          if (isCompleted)
            IconButton(
              icon: Icon(Icons.picture_as_pdf_rounded, color: primaryBlue),
              onPressed: () => _exportToPDF(settings),
            ),
          SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchMatchUpdate,
        color: primaryBlue,
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 20),
              _buildMatchHeader(primaryBlue),
              SizedBox(height: 32),
              _buildCustomTabs(primaryBlue),
              SizedBox(height: 32),
              if (match['status'] == 'completed') _buildWinnerBanner(primaryBlue),
              if (_activeTab == 0)
                ...inningsList.asMap().entries.map((entry) => _buildInningsView(entry.value, entry.key, primaryBlue, settings)).toList()
              else
                _buildMatchInfo(match, primaryBlue, settings),
              SizedBox(height: 40),
              AppFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMatchHeader(Color primaryBlue) {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: primaryBlue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: primaryBlue.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Text(match['series']?.toString().toUpperCase() ?? 'SMCC LEAGUE', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 2)),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _headerTeam(match['teamA'], primaryBlue),
              Column(
                children: [
                   Container(
                     padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                     decoration: BoxDecoration(color: primaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(100)),
                     child: Text('VS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: primaryBlue, fontSize: 10)),
                   ),
                ],
              ),
              _headerTeam(match['teamB'], primaryBlue),
            ],
          ),
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_on_rounded, size: 12, color: primaryBlue),
              SizedBox(width: 4),
              Text(match['venue']?.toString().toUpperCase() ?? 'TBD', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerTeam(String name, Color primaryBlue) {
    return Expanded(
      child: FittedBox(fit: BoxFit.scaleDown, child: Text(name.toUpperCase(), textAlign: TextAlign.center, style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16))),
    );
  }

  Widget _buildCustomTabs(Color primaryBlue) {
    return Container(
      padding: EdgeInsets.all(6),
      decoration: BoxDecoration(color: primaryBlue.withOpacity(0.05), borderRadius: BorderRadius.circular(100)),
      child: Row(
        children: [
          _tabItem('FULL SCORECARD', 0, primaryBlue),
          _tabItem('MATCH INFO', 1, primaryBlue),
        ],
      ),
    );
  }

  Widget _tabItem(String label, int index, Color primaryBlue) {
    bool active = _activeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = index),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? primaryBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(100),
            boxShadow: active ? [BoxShadow(color: primaryBlue.withOpacity(0.3), blurRadius: 10, offset: Offset(0, 4))] : [],
          ),
          child: Text(label, textAlign: TextAlign.center, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: active ? Colors.white : Colors.grey)),
        ),
      ),
    );
  }

  Widget _buildWinnerBanner(Color primaryBlue) {
    return Container(
      margin: EdgeInsets.only(bottom: 32),
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.green.shade600, Colors.green.shade400]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 15, offset: Offset(0, 5))]
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(_calculateWinner(match).toUpperCase(), textAlign: TextAlign.center, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildInningsView(dynamic inn, int idx, Color primaryBlue, SettingsProvider settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(idx >= 2 ? 'SUPER OVER' : inn['team'].toUpperCase(), style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14, color: primaryBlue)),
            Text('${inn['runs']}/${inn['wickets']} (${inn['overs']})', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14, color: primaryBlue)),
          ],
        ),
        SizedBox(height: 16),
        _buildBattingTable(inn['batting'] ?? []),
        SizedBox(height: 12),
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.grey.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('EXTRAS: ${inn['extras']['total']}', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey)),
              Text('(wd ${inn['extras']['wides']}, nb ${inn['extras']['noBalls']}, b ${inn['extras']['byes'] ?? 0}, lb ${inn['extras']['legByes'] ?? 0})', style: GoogleFonts.outfit(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        SizedBox(height: 24),
        _buildStatsBreakdown(inn),
        SizedBox(height: 24),
        _buildBowlingTable(inn, idx, primaryBlue, settings),
        SizedBox(height: 48),
      ],
    );
  }

  Widget _buildBattingTable(List<dynamic> batting) {
    return Column(
      children: [
        _tableHeader(['BATTER', 'R', 'B', '4s', '6s', 'SR']),
        ...batting.map((b) => _tableRow([
          _toCamelCase(b['player']),
          b['runs'].toString(),
          b['balls'].toString(),
          (b['fours'] ?? 0).toString(),
          (b['sixes'] ?? 0).toString(),
          b['strikeRate'].toString()
        ], isName: true, subText: b['status'])),
      ],
    );
  }

  Widget _buildBowlingTable(dynamic inn, int idx, Color primaryBlue, SettingsProvider settings) {
    int bowlIdx = idx % 2 == 0 ? idx + 1 : idx - 1;
    List<dynamic> bowling = [];
    if (match['innings'] != null && (match['innings'] as List).length > bowlIdx) {
       bowling = (match['innings'] as List)[bowlIdx]['bowling'] ?? [];
    }
    if (bowling.isEmpty) return SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('BOWLING ANALYSIS', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.5)),
        SizedBox(height: 16),
        _tableHeader(['BOWLER', 'O', 'R', 'W', 'wd', 'nb', 'ECO']),
        ...bowling.map((b) => _tableRow([
          _toCamelCase(b['player']),
          b['overs'].toString(),
          b['runs'].toString(),
          b['wickets'].toString(),
          (b['wides'] ?? 0).toString(),
          (b['noBalls'] ?? 0).toString(),
          b['economy'].toString()
        ], isName: true, highlightIdx: 3)),
      ],
    );
  }

  Widget _tableHeader(List<String> labels) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Row(
        children: labels.asMap().entries.map((e) => Expanded(
          flex: e.key == 0 ? 3 : 1,
          child: Text(e.value, textAlign: e.key == 0 ? TextAlign.start : TextAlign.center, style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey)),
        )).toList(),
      ),
    );
  }

  Widget _tableRow(List<String> values, {bool isName = false, String? subText, int? highlightIdx}) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.05))),
      ),
      child: Row(
        children: values.asMap().entries.map((e) => Expanded(
          flex: e.key == 0 ? 3 : 1,
          child: Column(
            crossAxisAlignment: e.key == 0 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              Text(e.value, style: GoogleFonts.outfit(fontSize: 11, fontWeight: (e.key == 0 || e.key == highlightIdx) ? FontWeight.w900 : FontWeight.bold, color: e.key == highlightIdx ? Colors.red : null)),
              if (e.key == 0 && subText != null) Text(subText, style: GoogleFonts.outfit(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)),
            ],
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildStatsBreakdown(dynamic inn) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(color: Color(0xFF2563EB).withOpacity(0.03), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem('DOTS', (inn['dots'] ?? 0).toString()),
          _statItem('1s', (inn['ones'] ?? 0).toString()),
          _statItem('2s', (inn['twos'] ?? 0).toString()),
          _statItem('4s', (inn['fours'] ?? 0).toString(), high: true),
          _statItem('6s', (inn['sixes'] ?? 0).toString(), high: true),
        ],
      ),
    );
  }

  Widget _statItem(String l, String v, {bool high = false}) {
    return Column(
      children: [
        Text(v, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: high ? Color(0xFF2563EB) : null)),
        Text(l, style: GoogleFonts.outfit(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _buildMatchInfo(dynamic match, Color primaryBlue, SettingsProvider settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoCard('Match Logistics', [
          {'l': 'Series', 'v': match['series'] ?? 'SMCC League'},
          {'l': 'Venue', 'v': match['venue'] ?? 'TBD'},
          {'l': 'Date', 'v': match['date']?.toString().split('T')[0] ?? 'TBD'},
          {'l': 'Match Status', 'v': match['status'].toUpperCase()},
        ], primaryBlue),
        SizedBox(height: 32),
        _infoCard('Tournament Regulations', [
          {'l': 'Bowling', 'v': 'Strictly Pure Overarm'},
          {'l': 'Leg Side Wide', 'v': 'Applicable'},
          {'l': 'LBW', 'v': 'Not Applicable'},
          {'l': 'Super Over', 'v': 'Applicable for Ties'},
        ], primaryBlue),
      ],
    );
  }

  Widget _infoCard(String title, List<Map<String, String>> items, Color primaryBlue) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(color: primaryBlue.withOpacity(0.03), borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: primaryBlue, letterSpacing: 2)),
          SizedBox(height: 24),
          ...items.map((it) => Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(it['l']!, style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                Text(it['v']!, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900)),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  String _calculateWinner(dynamic match) {
    try {
      if (match == null || match['innings'] == null) return "Match Completed";
      List innings = match['innings'] is List ? match['innings'] : [];
      if (innings.length < 2) return "Match Completed";
      
      dynamic inn1 = innings[0], inn2 = innings[1];
      bool isSuperOver = innings.length > 2;
      if (innings.length >= 4) { 
        inn1 = innings[innings.length - 2]; 
        inn2 = innings[innings.length - 1]; 
      }
      
      if (inn1 == null || inn2 == null) return "Match Completed";
      
      int r1 = (inn1['runs'] as num?)?.toInt() ?? 0;
      int r2 = (inn2['runs'] as num?)?.toInt() ?? 0;
      
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
      return "Match Completed";
    }
  }

  String _toCamelCase(String text) {
    if (text.isEmpty) return text;
    return text.trim().split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  Future<void> _exportToPDF(SettingsProvider settings) async {
    final pdf = pw.Document();
    final String winner = _calculateWinner(match);
    final primaryColor = PdfColor.fromInt(0xFF009270); // SMCC Green

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("SMCC CRICKET SCORECARD", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                  pw.SizedBox(height: 8),
                  pw.Text("${match['teamA'].toString().toUpperCase()} VS ${match['teamB'].toString().toUpperCase()}", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                  pw.SizedBox(height: 4),
                  pw.Text("SERIES: ${match['series']?.toString().toUpperCase() ?? 'SMCC'} | VENUE: ${match['venue'].toString().toUpperCase()}", style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                  pw.Divider(height: 20),
                ]
              )
            ),
            if (match['status'] == 'completed') ...[
              pw.Container(
                padding: pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(color: primaryColor, borderRadius: pw.BorderRadius.circular(8)),
                child: pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text("RESULT: ${winner.toUpperCase()}", style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 14)),
                    ]
                  )
                )
              ),
              pw.SizedBox(height: 24),
            ],

            ...(match['innings'] as List).asMap().entries.map((entry) {
              final inn = entry.value;
              final idx = entry.key;
              final String title = idx >= 2 ? "SUPER OVER INNINGS" : "${inn['team'].toString().toUpperCase()} INNINGS";

              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Padding(
                    padding: pw.EdgeInsets.symmetric(vertical: 12),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(title, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                        pw.Text("${inn['runs']}/${inn['wickets']} (${inn['overs']} OV)", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      ]
                    )
                  ),
                  pw.Table.fromTextArray(
                    headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold),
                    headerDecoration: pw.BoxDecoration(color: primaryColor),
                    headers: ['Batter', 'Status', 'R', 'B', '4s', '6s', 'SR'],
                    data: (inn['batting'] as List).map((b) => [
                      b['player'], b['status'], b['runs'], b['balls'], b['fours'], b['sixes'], b['strikeRate']
                    ]).toList(),
                  ),
                  pw.Container(
                    padding: pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    decoration: pw.BoxDecoration(color: PdfColors.grey100),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text("EXTRAS: ${inn['extras']['total']}", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        pw.Text("(wd ${inn['extras']['wides']}, nb ${inn['extras']['noBalls']}, b ${inn['extras']['byes'] ?? 0}, lb ${inn['extras']['legByes'] ?? 0})", style: pw.TextStyle(fontSize: 8)),
                      ]
                    )
                  ),
                  pw.SizedBox(height: 16),
                  
                  // Bowling Table
                  pw.Table.fromTextArray(
                    headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold),
                    headerDecoration: pw.BoxDecoration(color: PdfColors.grey800),
                    headers: ['Bowler', 'O', 'M', 'R', 'W', 'ECON'],
                    data: (() {
                      int bowlIdx = idx % 2 == 0 ? idx + 1 : idx - 1;
                      if (match['innings'].length > bowlIdx) {
                        return (match['innings'][bowlIdx]['bowling'] as List).map((b) => [
                          b['player'], b['overs'], b['maiden'] ?? 0, b['runs'], b['wickets'], b['economy']
                        ]).toList();
                      }
                      return <List<dynamic>>[];
                    })(),
                  ),
                  pw.SizedBox(height: 32),
                ]
              );
            }).toList(),
            
            pw.Footer(
              trailing: pw.Text("Exported from SMCC Mobile app on ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}", style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500))
            )
          ];
        }
      )
    );

    final String filename = "${match['teamA']}_vs_${match['teamB']}_scorecard.pdf";
    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: filename);
  }
}
