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
        title: Text(settings.translate('full_scorecard'), style: TextStyle(fontWeight: FontWeight.black, fontSize: 16)),
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
                  Text('${widget.match['teamA']} vs ${widget.match['teamB']}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.black)),
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
            if (_activeTab == 0)
              ...inningsList.map((innings) => _buildInningsList(innings, settings)).toList()
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
          Text('ICC RULES & REGULATIONS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey)),
          SizedBox(height: 10),
          _ruleItem('Maximum of ${match['totalOvers']} overs per innings.'),
          _ruleItem('Bowler limit: Max 20% of total overs.'),
          _ruleItem('Free-hit for all front-foot no balls.'),
          _ruleItem('Wide: 1 extra run + re-bowl.'),
          _ruleItem('Strategic timeouts as per league rules.'),
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

  Widget _buildInningsList(dynamic innings, SettingsProvider settings) {
    List<dynamic> batting = innings['batting'] ?? [];
    
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
              Text('${innings['runs']}/${innings['wickets']} (${innings['overs']})', style: TextStyle(color: Colors.white, fontWeight: FontWeight.black)),
            ],
          ),
        ),
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
                _buildCell('', align: TextAlign.center),
              ],
            ),
          ],
        ),
        SizedBox(height: 20),
      ],
    );
  }

  Widget _buildCell(String text, {bool isHeader = false, bool isBold = false, bool isName = false, bool isSmall = false, TextAlign align = TextAlign.start}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontSize: isHeader ? 10 : (isSmall ? 10 : 12),
          fontWeight: (isHeader || isBold || isName) ? FontWeight.bold : FontWeight.normal,
          color: isHeader ? Colors.grey : (isName ? Colors.blue.shade600 : null),
        ),
      ),
    );
  }
}
