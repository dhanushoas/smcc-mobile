import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

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
                  Text('${widget.match['teamA']} vs ${widget.match['teamB']}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
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
                margin: EdgeInsets.all(20),
                padding: EdgeInsets.all(15),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Color(0xFF009270).withOpacity(0.1),
                  border: Border.all(color: Color(0xFF009270).withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  widget.match['manOfTheMatch'] != null 
                    ? '${settings.translate('man_of_the_match')}: ${widget.match['manOfTheMatch']}' 
                    : settings.translate('completed'),
                  style: TextStyle(color: Color(0xFF009270), fontWeight: FontWeight.bold, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            if (_activeTab == 0)
              ...inningsList.asMap().entries.map((entry) => _buildInningsList(entry.value, entry.key, widget.match, settings)).toList()
            else
              _buildMatchInfo(widget.match, settings),
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
            0: FlexColumnWidth(4),
            1: FlexColumnWidth(1),
            2: FlexColumnWidth(1),
            3: FlexColumnWidth(1.2),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(color: settings.isDarkMode ? Colors.black26 : Colors.grey.shade50),
              children: [
                _buildCell(settings.translate('batter'), isHeader: true),
                _buildCell(settings.translate('runs'), isHeader: true, align: TextAlign.center),
                _buildCell(settings.translate('balls'), isHeader: true, align: TextAlign.center),
                _buildCell(settings.translate('sr'), isHeader: true, align: TextAlign.center),
              ],
            ),
            ...batting.map((b) => TableRow(
              children: [
                _buildCell('${b['player']}\n${b['status']}', isName: true),
                _buildCell(b['runs'].toString(), isBold: true, align: TextAlign.center),
                _buildCell(b['balls'].toString(), align: TextAlign.center),
                _buildCell(b['strikeRate'].toString(), isSmall: true, align: TextAlign.center),
              ],
            )).toList(),
            TableRow(
              children: [
                _buildCell(settings.translate('extras'), isSmall: true),
                _buildCell(innings['extras']['total'].toString(), isBold: true, align: TextAlign.center),
                _buildCell('', align: TextAlign.center),
                _buildCell('(wd ${innings['extras']['wides']}, nb ${innings['extras']['noBalls']}, b ${innings['extras']['byes'] ?? 0}, lb ${innings['extras']['legByes'] ?? 0})', isSmall: true, align: TextAlign.end),
              ],
            ),
          ],
        ),

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
              0: FlexColumnWidth(4),
              1: FlexColumnWidth(1),
              2: FlexColumnWidth(1),
              3: FlexColumnWidth(1),
              4: FlexColumnWidth(1.2),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(color: settings.isDarkMode ? Color(0xFF1A1A1A) : Colors.white),
                children: [
                  _buildCell(settings.translate('bowler'), isHeader: true),
                  _buildCell('O', isHeader: true, align: TextAlign.center),
                  _buildCell('R', isHeader: true, align: TextAlign.center),
                  _buildCell('W', isHeader: true, align: TextAlign.center),
                  _buildCell('ECO', isHeader: true, align: TextAlign.center),
                ],
              ),
              ...bowling.map((bowl) => TableRow(
                children: [
                  _buildCell(bowl['player'], isBold: true),
                  _buildCell(bowl['overs'].toString(), align: TextAlign.center),
                  _buildCell(bowl['runs'].toString(), align: TextAlign.center),
                  _buildCell(bowl['wickets'].toString(), isBold: true, align: TextAlign.center, color: Colors.red),
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
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontSize: isHeader ? 10 : (isSmall ? 10 : 12),
          fontWeight: (isHeader || isBold || isName) ? FontWeight.bold : FontWeight.normal,
          color: color ?? (isHeader ? Colors.grey : (isName ? Colors.blue.shade600 : null)),
        ),
      ),
    );
  }
}
