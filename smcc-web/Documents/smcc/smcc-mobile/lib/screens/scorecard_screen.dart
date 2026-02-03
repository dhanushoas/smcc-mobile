import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../providers/settings_provider.dart';
import '../widgets/app_footer.dart';

class ScorecardScreen extends StatefulWidget {
  final dynamic match;

  ScorecardScreen({required this.match});

  @override
  _ScorecardScreenState createState() => _ScorecardScreenState();
}

class _ScorecardScreenState extends State<ScorecardScreen> {
  int _activeTab = 0; // 0 for Scorecard, 1 for Match Info

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    List<dynamic> inningsList = widget.match['innings'] ?? [];
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: settings.isDarkMode ? Color(0xFF1E1E1E) : Color(0xFF222222),
        elevation: 0,
        title: Text(settings.translate('full_scorecard'), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        actions: [
          if (widget.match['status'] == 'completed')
            IconButton(
              icon: Icon(Icons.picture_as_pdf),
              onPressed: () => _exportToPDF(settings),
              tooltip: 'Export to PDF',
            ),
          IconButton(
            icon: Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${widget.match['teamA'].toString().toUpperCase()} vs ${widget.match['teamB'].toString().toUpperCase()}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  SizedBox(height: 4),
                  Text('${widget.match['series'] ?? 'SMCC League'} | ${widget.match['venue']}', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  if (widget.match['status'] == 'completed')
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text('${settings.translate('completed')}', style: TextStyle(color: Color(0xFF009270), fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                ],
              ),
            ),
            Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _activeTab = 0),
                    child: _buildTab(settings.translate('full_scorecard'), isActive: _activeTab == 0, settings: settings),
                  ),
                  SizedBox(width: 20),
                  GestureDetector(
                    onTap: () => setState(() => _activeTab = 1),
                    child: _buildTab(settings.translate('match_info'), isActive: _activeTab == 1, settings: settings),
                  ),
                ],
              ),
            ),
            if (widget.match['status'] == 'completed')
              Container(
                margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                padding: EdgeInsets.all(15),
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFF009270), Color(0xFF00BFA5)]),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))]
                ),
                child: Column(
                  children: [
                    Text(
                      _calculateWinner(widget.match).toUpperCase(),
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    if (widget.match['manOfTheMatch'] != null) ...[
                      SizedBox(height: 8),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                        child: Text(
                          '🏅 ${settings.translate('man_of_the_match')}: ${widget.match['manOfTheMatch']}',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ]
                  ],
                ),
              ),
            if (_activeTab == 0)
              ...inningsList.asMap().entries.map((entry) => _buildInningsList(entry.value, entry.key, widget.match, settings)).toList()
            else
              _buildMatchInfo(widget.match, settings),
            AppFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String label, {bool isActive = false, required SettingsProvider settings}) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: isActive ? Color(0xFF009270) : Colors.grey, fontWeight: FontWeight.bold, fontSize: 13)),
        if (isActive) Container(margin: EdgeInsets.only(top: 4), height: 3, width: 24, color: Color(0xFF009270)),
      ],
    );
  }

  Widget _buildMatchInfo(dynamic match, SettingsProvider settings) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoRow(settings.translate('series'), match['series'] ?? 'SMCC Premier League'),
          _infoRow(settings.translate('venue'), match['venue'] ?? '-'),
          _infoRow(settings.translate('date'), match['date'] != null ? match['date'].toString().split('T')[0] : '-'),
          _infoRow('TOTAL OVERS', '${match['totalOvers']} Overs', isSpecial: true),
          SizedBox(height: 30),
          Text('ICC MATCH RULES & FORMAT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey[700])),
          SizedBox(height: 10),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
            child: Column(
              children: [
                 _ruleItem('Match Format: T20 International Standard (${match['totalOvers']} Overs).'),
                 _ruleItem('Powerplay (P1): Overs 1-6 are mandatory (Max 2 fielders outside circle).'),
                 _ruleItem('Bowling Limit: Max ${(match['totalOvers'] * 0.2).toStringAsFixed(0)} Overs per bowler.'),
                 _ruleItem('Pure Bowling Action: Elbow extension < 15 degrees (ICC Regs).'),
                 _ruleItem('Wide: 1 Run + Re-bowl (Strict leg-side).'),
                 _ruleItem('No Ball: 1 Run + Re-bowl + Free Hit.'),
                 _ruleItem('Dismissals: Bowled, Caught, LBW, Run Out, Stumped, Hit Wicket.'),
                 _ruleItem('Tie Breaker: Super Over.'),
                 _ruleItem('Substitutes: Concussion substitute allowed.'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool isSpecial = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(label, style: TextStyle(color: Colors.grey, fontSize: 13))),
          Expanded(flex: 3, child: Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isSpecial ? Color(0xFF009270) : null))),
        ],
      ),
    );
  }

  Widget _ruleItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF009270))),
          Expanded(child: Text(text, style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
        ],
      ),
    );
  }

  Widget _buildInningsList(dynamic innings, int inningsIdx, dynamic match, SettingsProvider settings) {
    List<dynamic> batting = innings['batting'] ?? [];
    
    // Find bowling for this innings
    // The bowling team is the OTHER team in the match
    int bowlingInningsIdx = inningsIdx == 0 ? 1 : 0;
    List<dynamic> bowling = [];
    if (match['innings'] != null && match['innings'].length > bowlingInningsIdx) {
       bowling = match['innings'][bowlingInningsIdx]['bowling'] ?? [];
    }
    
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Color(0xFF009270),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(innings['team'], style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Text('${innings['runs']}/${innings['wickets']} (${innings['overs']})', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
        
        // Batting Table
        Table(
          columnWidths: {
            0: FlexColumnWidth(3),
            1: FlexColumnWidth(0.8),
            2: FlexColumnWidth(0.8),
            3: FlexColumnWidth(0.8),
            4: FlexColumnWidth(0.8),
            5: FlexColumnWidth(1.2),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(color: settings.isDarkMode ? Colors.black26 : Colors.grey.shade50),
              children: [
                _buildCell(settings.translate('batter'), isHeader: true),
                _buildCell('R', isHeader: true, align: TextAlign.center),
                _buildCell('B', isHeader: true, align: TextAlign.center),
                _buildCell('4s', isHeader: true, align: TextAlign.center),
                _buildCell('6s', isHeader: true, align: TextAlign.center),
                _buildCell(settings.translate('sr'), isHeader: true, align: TextAlign.center),
              ],
            ),
            ...batting.map((b) => TableRow(
              children: [
                _buildCell('${b['player']}\n${b['status']}', isName: true),
                _buildCell(b['runs'].toString(), isBold: true, align: TextAlign.center),
                _buildCell(b['balls'].toString(), align: TextAlign.center),
                _buildCell((b['fours'] ?? 0).toString(), align: TextAlign.center),
                _buildCell((b['sixes'] ?? 0).toString(), align: TextAlign.center),
                _buildCell(b['strikeRate'].toString(), isSmall: true, align: TextAlign.center),
              ],
            )).toList(),
            TableRow(
              children: [
                _buildCell(settings.translate('extras'), isSmall: true),
                _buildCell(innings['extras']['total'].toString(), isBold: true, align: TextAlign.center),
                _buildCell('', align: TextAlign.center),
                _buildCell('', align: TextAlign.center),
                _buildCell('', align: TextAlign.center),
                _buildCell('(wd ${innings['extras']['wides']}, nb ${innings['extras']['noBalls']}, b ${innings['extras']['byes'] ?? 0}, lb ${innings['extras']['legByes'] ?? 0})', isSmall: true, align: TextAlign.end),
              ],
            ),
          ],
        ),

        // Team Run Breakdown Section
        Container(
          width: double.infinity,
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: settings.isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: settings.isDarkMode ? Colors.white10 : Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('TEAM STATS & RUN BREAKDOWN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
              SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _statItem('DOTS', (innings['dots'] ?? 0).toString()),
                  _statItem('1s', (innings['ones'] ?? 0).toString()),
                  _statItem('2s', (innings['twos'] ?? 0).toString()),
                  _statItem('3s', (innings['threes'] ?? 0).toString()),
                  _statItem('4s', (innings['fours'] ?? 0).toString(), isHighlight: true),
                  _statItem('6s', (innings['sixes'] ?? 0).toString(), isHighlight: true),
                ],
              ),
            ],
          ),
        ),
        
        // Fall of Wickets
        if (innings['fow'] != null && (innings['fow'] as List).isNotEmpty) ...[
          SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            color: settings.isDarkMode ? Colors.white10 : Colors.grey.shade100,
            child: Text('FALL OF WICKETS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600, letterSpacing: 1)),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: (innings['fow'] as List).map((f) => Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
                child: Text(
                  '${f['wicket']}-${f['runs']} (${f['player']}, ${f['overs']} ov)',
                  style: TextStyle(fontSize: 10),
                ),
              )).toList(),
            ),
          ),
        ],

        // Bowling Table
        if (bowling.isNotEmpty) ...[
          SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            color: settings.isDarkMode ? Colors.white10 : Colors.grey.shade200,
            child: Text(settings.translate('bowling').toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
          ),
          Table(
            columnWidths: {
              0: FlexColumnWidth(3),
              1: FlexColumnWidth(0.8),
              2: FlexColumnWidth(0.8),
              3: FlexColumnWidth(0.8),
              4: FlexColumnWidth(0.8),
              5: FlexColumnWidth(0.8),
              6: FlexColumnWidth(1.2),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(color: settings.isDarkMode ? Color(0xFF1A1A1A) : Colors.white),
                children: [
                _buildCell(settings.translate('bowler'), isHeader: true),
                _buildCell('O', isHeader: true, align: TextAlign.center),
                _buildCell('R', isHeader: true, align: TextAlign.center),
                _buildCell('W', isHeader: true, align: TextAlign.center),
                _buildCell('wd', isHeader: true, align: TextAlign.center),
                _buildCell('nb', isHeader: true, align: TextAlign.center),
                _buildCell('ECO', isHeader: true, align: TextAlign.center),
                ],
              ),
              ...bowling.map((bowl) => TableRow(
                children: [
                  _buildCell(bowl['player'], isBold: true),
                  _buildCell(bowl['overs'].toString(), align: TextAlign.center),
                  _buildCell(bowl['runs'].toString(), align: TextAlign.center),
                  _buildCell(bowl['wickets'].toString(), isBold: true, align: TextAlign.center, color: Colors.red),
                  _buildCell((bowl['wides'] ?? 0).toString(), align: TextAlign.center),
                  _buildCell((bowl['noBalls'] ?? 0).toString(), align: TextAlign.center),
                  _buildCell(bowl['economy'].toString(), isSmall: true, align: TextAlign.center),
                ],
              )).toList(),
            ],
          ),
        ],
        SizedBox(height: 30),
      ],
    );
  }

  Widget _buildCell(String text, {bool isHeader = false, bool isBold = false, bool isName = false, bool isSmall = false, TextAlign align = TextAlign.start, Color? color}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontSize: isHeader ? 9 : (isSmall ? 9 : 11),
          fontWeight: (isHeader || isBold || isName) ? FontWeight.bold : FontWeight.normal,
          color: color ?? (isHeader ? Colors.grey : (isName ? Colors.blue.shade600 : null)),
        ),
      ),
    );
  }

  Widget _statItem(String label, String value, {bool isHighlight = false}) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: isHighlight ? Color(0xFF009270) : null)),
        Text(label, style: TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)),
      ],
    );
  }
  String _calculateWinner(dynamic match) {
    List<dynamic> innings = match['innings'] ?? [];
    if (innings.length < 2) return "Match Completed";
    
    var inn1 = innings[0];
    var inn2 = innings[1];
    
    int runs1 = inn1['runs'] ?? 0;
    int runs2 = inn2['runs'] ?? 0;
    
    if (runs1 > runs2) {
      return "${inn1['team']} won by ${runs1 - runs2} runs";
    } else if (runs2 >= runs1) {
      int wkts = 10 - ((inn2['wickets'] ?? 0) as num).toInt();
      return "${inn2['team']} won by $wkts wickets";
    }
    return "Match Drawn";
  }

  Future<void> _exportToPDF(SettingsProvider settings) async {
    final pdf = pw.Document();
    final match = widget.match;
    final String result = _calculateWinner(match);
    
    String dateTimeStr = "-";
    try {
      if (match['date'] != null) {
        dateTimeStr = "${DateFormat('dd MMM yyyy').format(DateTime.parse(match['date']))} ${match['time'] ?? ''}";
      }
    } catch (e) {}

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text("SMCC CRICKET CLUB", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                  pw.SizedBox(height: 5),
                  pw.Text("${match['teamA']} VS ${match['teamB']}", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 5),
                  pw.Text("Venue: ${match['venue'] ?? 'TBD'} | Date: $dateTimeStr", style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  pw.Divider(),
                ]
              )
            ),
            pw.SizedBox(height: 10),
            pw.Center(
               child: pw.Column(
                 children: [
                   pw.Text(result.toUpperCase(), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
                   if (match['manOfTheMatch'] != null)
                     pw.Text("MAN OF THE MATCH: ${match['manOfTheMatch']}", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                 ]
               )
            ),
            pw.SizedBox(height: 20),

            ...(match['innings'] as List? ?? []).map((inn) {
               return pw.Column(
                 crossAxisAlignment: pw.CrossAxisAlignment.start,
                 children: [
                   pw.Container(
                     padding: const pw.EdgeInsets.all(5),
                     width: double.infinity,
                     color: PdfColors.grey200,
                     child: pw.Text("${inn['team']} Innings: ${inn['runs']}/${inn['wickets']} (${inn['overs']} Ov)", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                   ),
                   pw.SizedBox(height: 10),
                   pw.TableHelper.fromTextArray(
                     headers: ['Batter', 'Status', 'R', 'B', '4s', '6s', 'SR'],
                     data: (inn['batting'] as List? ?? []).map((b) => [b['player'], b['status'], b['runs'], b['balls'], b['fours'] ?? 0, b['sixes'] ?? 0, b['strikeRate']]).toList(),
                     headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                     cellStyle: pw.TextStyle(fontSize: 9),
                     cellAlignment: pw.Alignment.centerLeft,
                   ),
                   pw.SizedBox(height: 5),
                   pw.Row(
                     mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                     children: [
                       pw.Text("Extras: ${inn['extras']['total']} (wd ${inn['extras']['wides']}, nb ${inn['extras']['noBalls']}, b ${inn['extras']['byes'] ?? 0}, lb ${inn['extras']['legByes'] ?? 0})", style: pw.TextStyle(fontSize: 9)),
                       pw.Text("Breakdown: Dots: ${inn['dots'] ?? 0}, 1s: ${inn['ones'] ?? 0}, 2s: ${inn['twos'] ?? 0}, 3s: ${inn['threes'] ?? 0}, 4s: ${inn['fours'] ?? 0}, 6s: ${inn['sixes'] ?? 0}", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                     ]
                   ),
                   pw.SizedBox(height: 10),
                   pw.TableHelper.fromTextArray(
                     headers: ['Bowler', 'O', 'M', 'R', 'W', 'wd', 'nb', 'Eco'],
                     data: (inn['bowling'] as List? ?? []).map((b) => [b['player'], b['overs'], b['maidens'], b['runs'], b['wickets'], b['wides'] ?? 0, b['noBalls'] ?? 0, b['economy']]).toList(),
                     headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                     cellStyle: pw.TextStyle(fontSize: 9),
                     cellAlignment: pw.Alignment.centerLeft,
                   ),
                   pw.SizedBox(height: 20),
                 ]
               );
            }).toList(),
            
            pw.Divider(),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text("Scorecard generated by SMCC Live App on ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}", style: pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
            )
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: '${match['teamA']}_vs_${match['teamB']}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf'
    );
  }
}
