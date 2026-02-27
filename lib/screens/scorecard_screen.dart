/// scorecard_screen.dart — Full port of smcc-web/src/pages/FullScorecard.jsx
/// Innings tabs, batting/bowling/extras/FoW tables, target badge (singular/plural),
/// match result, Man of the Match, and PDF download.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../services/api_service.dart';
import '../utils/formatters.dart';
import '../utils/calculations.dart';

class ScorecardScreen extends StatefulWidget {
  final String matchId;
  const ScorecardScreen({Key? key, required this.matchId}) : super(key: key);

  @override
  State<ScorecardScreen> createState() => _ScorecardScreenState();
}

class _ScorecardScreenState extends State<ScorecardScreen> with SingleTickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────────
  Map<String, dynamic>? _match;
  bool _loading = true;
  int _activeInnings = 0;
  String _activeTab = 'scorecard'; // 'scorecard' | 'info'

  // Boundary animation (mirrors FullScorecard.jsx)
  int _blastValue = 0;
  bool _showBlast = false;

  late io.Socket _socket;

  // ── Theme ──────────────────────────────────────────────────────────────────
  static const Color _primary  = Color(0xFF2563EB);
  static const Color _danger   = Color(0xFFDC2626);
  static const Color _success  = Color(0xFF059669);

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _fetchMatch();
    _connectSocket();
  }

  @override
  void dispose() {
    _socket.dispose();
    super.dispose();
  }

  // ── Data ───────────────────────────────────────────────────────────────────
  Future<void> _fetchMatch() async {
    try {
      final data = await ApiService.getMatch(widget.matchId);
      setState(() {
        _match = data;
        _loading = false;
        _setActiveInnings(data);
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  /// Mirrors FullScorecard.jsx auto-select active innings logic
  void _setActiveInnings(Map<String, dynamic> data) {
    final status = data['status'] as String? ?? '';
    final innings = List<dynamic>.from(data['innings'] ?? []);
    if ((status == 'live' || status == 'completed') && innings.isNotEmpty) {
      final bTeam = data['score']?['battingTeam'] as String?;
      if (bTeam != null) {
        final reversed = List.generate(innings.length, (i) => {'inn': innings[i], 'idx': i}).reversed;
        final active = reversed.firstWhere(
          (x) => (x['inn']['team'] as String?)?.trim().toLowerCase() == bTeam.trim().toLowerCase(),
          orElse: () => {'idx': innings.length - 1},
        );
        _activeInnings = active['idx'] as int;
      } else {
        _activeInnings = innings.length - 1;
      }
    }
  }

  void _connectSocket() {
    _socket = io.io(ApiService.socketUrl, <String, dynamic>{
      'transports': ['websocket'], 'autoConnect': true,
    });
    _socket.on('matchUpdate', (updated) {
      if (updated['_id'] != widget.matchId && updated['id'] != widget.matchId) return;
      setState(() {
        if (_match != null && updated['status'] == 'live') {
          final oldRuns = (_match!['score']?['runs'] as num? ?? 0).toInt();
          final newRuns = (updated['score']?['runs'] as num? ?? 0).toInt();
          final diff = newRuns - oldRuns;
          if (diff == 4 || diff == 6) {
            _blastValue = diff;
            _showBlast = true;
            Timer(const Duration(milliseconds: 2500), () {
              if (mounted) setState(() => _showBlast = false);
            });
          }
        }
        _match = Map<String, dynamic>.from(updated);
      });
    });
  }

  // ── PDF Generation (mirrors AdminDashboard.jsx downloadPDF) ────────────────
  Future<void> _downloadPDF() async {
    final match = _match!;
    final doc = pw.Document();
    final innings = List<dynamic>.from(match['innings'] ?? []);
    final result = calculateWinner(match);

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (ctx) {
        final widgets = <pw.Widget>[];

        // Header
        widgets.add(pw.Text(
          '${match['teamA']?.toString().toUpperCase()} VS ${match['teamB']?.toString().toUpperCase()} — FULL SCORECARD',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16),
        ));
        widgets.add(pw.SizedBox(height: 4));
        final dateParsed = DateTime.tryParse(match['date'] ?? '') ?? DateTime.now();
        widgets.add(pw.Text(
          'SERIES: ${(match['series'] ?? 'SMCC').toString().toUpperCase()} | VENUE: ${(match['venue'] ?? '').toString().toUpperCase()} | DATE: ${dateParsed.toLocal().toString().split('.')[0].toUpperCase()}',
          style: pw.TextStyle(fontSize: 9),
        ));

        if (result != null) {
          widgets.add(pw.SizedBox(height: 8));
          widgets.add(pw.Text('RESULT: ${result.toUpperCase()}',
              style: pw.TextStyle(color: PdfColors.green700, fontWeight: pw.FontWeight.bold, fontSize: 12)));
          if (match['manOfTheMatch'] != null) {
            widgets.add(pw.Text('POTM: ${match['manOfTheMatch'].toString().toUpperCase()}',
                style: pw.TextStyle(fontSize: 10)));
          }
        }
        widgets.add(pw.SizedBox(height: 16));

        // Innings
        for (int idx = 0; idx < innings.length; idx++) {
          final inn = innings[idx] as Map<String, dynamic>;
          if (idx >= 2 && (inn['runs'] ?? 0) == 0 && (inn['wickets'] ?? 0) == 0 &&
              (inn['batting'] as List? ?? []).isEmpty) continue;

          final ordinal = _ordinal(idx + 1);
          final isSO = idx >= 2;
          final title = '${inn['team']?.toString().toUpperCase()} $ordinal INNINGS${isSO ? ' (SUPER OVER)' : ''}';
          final ovs = (inn['overs'] as num? ?? 0);
          final ovsStr = '${inn['runs']}/${inn['wickets']} (${ovs}OV)';
          widgets.add(pw.Text('$title: $ovsStr',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13, color: PdfColors.blue800)));
          widgets.add(pw.SizedBox(height: 6));

          // Batting table
          final batting = List<dynamic>.from(inn['batting'] ?? []);
          if (batting.isNotEmpty) {
            widgets.add(pw.TableHelper.fromTextArray(
              headers: ['Batter', 'Status', 'R', 'B', '4s', '6s', 'SR'],
              data: batting.map((b) => [
                b['player']?.toString().toUpperCase() ?? '',
                b['status']?.toString().toUpperCase() ?? '',
                '${b['runs'] ?? 0}',
                '${b['balls'] ?? 0}',
                '${b['fours'] ?? 0}',
                '${b['sixes'] ?? 0}',
                '${b['strikeRate'] ?? 0}',
              ]).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.green700),
              cellStyle: const pw.TextStyle(fontSize: 9),
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            ));
          }

          // Extras
          final ext = inn['extras'] as Map<String, dynamic>? ?? {};
          widgets.add(pw.SizedBox(height: 4));
          widgets.add(pw.Text(
            'EXTRAS: ${ext['total'] ?? 0} (wd ${ext['wides'] ?? 0}, nb ${ext['noBalls'] ?? 0}, b ${ext['byes'] ?? 0}, lb ${ext['legByes'] ?? 0})',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ));

          // Hit Breakdown
          widgets.add(pw.Text(
            'HIT BREAKDOWN: Dots:${inn['dots'] ?? 0} | 1s:${inn['ones'] ?? 0} | 2s:${inn['twos'] ?? 0} | 3s:${inn['threes'] ?? 0} | 4s:${inn['fours'] ?? 0} | 6s:${inn['sixes'] ?? 0}',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ));
          widgets.add(pw.SizedBox(height: 6));

          // Bowling table (from the opposing innings)
          final bowlInnIdx = idx.isEven ? idx + 1 : idx - 1;
          if (bowlInnIdx < innings.length) {
            final bowlInn = innings[bowlInnIdx] as Map<String, dynamic>;
            final bowling = List<dynamic>.from(bowlInn['bowling'] ?? []);
            if (bowling.isNotEmpty) {
              widgets.add(pw.TableHelper.fromTextArray(
                headers: ['Bowler', 'O', 'M', 'R', 'W', 'WD', 'NB', 'ECO'],
                data: bowling.map((b) => [
                  b['player']?.toString().toUpperCase() ?? '',
                  '${b['overs'] ?? 0}',
                  '${b['maidens'] ?? 0}',
                  '${b['runs'] ?? 0}',
                  '${b['wickets'] ?? 0}',
                  '${b['wides'] ?? 0}',
                  '${b['noBalls'] ?? 0}',
                  '${b['economy'] ?? 0}',
                ]).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey800),
                cellStyle: const pw.TextStyle(fontSize: 9),
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              ));
            }
          }

          // Fall of Wickets
          final fow = List<dynamic>.from(inn['fallOfWickets'] ?? []);
          if (fow.isNotEmpty) {
            widgets.add(pw.SizedBox(height: 6));
            widgets.add(pw.Text('FALL OF WICKETS',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.red700, fontSize: 10)));
            widgets.add(pw.TableHelper.fromTextArray(
              headers: ['Wkt', 'Score', 'Over', 'Player'],
              data: fow.map((f) => ['${f['wicket']}', '${f['runs']}', '${f['overs']}', f['player']?.toString().toUpperCase() ?? '']).toList(),
              cellStyle: const pw.TextStyle(fontSize: 9),
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            ));
          }

          // Total line — with correct singular/plural
          final innOvers = (inn['overs'] as num? ?? 0).toDouble();
          final oversWord = innOvers == 1 ? 'Over' : 'Overs';
          widgets.add(pw.SizedBox(height: 4));
          widgets.add(pw.Text(
            'TOTAL: ${inn['runs']}/${inn['wickets']} in $innOvers $oversWord | Boundaries: 4s: ${inn['fours'] ?? 0}, 6s: ${inn['sixes'] ?? 0}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
          ));
          widgets.add(pw.SizedBox(height: 16));
        }

        return widgets;
      },
    ));

    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }

  String _ordinal(int n) {
    final s = ['th', 'st', 'nd', 'rd'];
    final v = n % 100;
    return '$n${s[(v - 20) % 10 >= 0 && (v - 20) % 10 < s.length ? (v - 20) % 10 : (v < s.length ? v : 0)]}';
  }

  // ── UI ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text('Full Scorecard', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
        actions: [
          if (_match != null && _match!['status'] == 'completed')
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'Export PDF',
              onPressed: _downloadPDF,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _match == null
              ? Center(child: Text('Match not found', style: GoogleFonts.outfit()))
              : Stack(children: [
                  _buildBody(),
                  if (_showBlast) _buildBoundaryOverlay(),
                ]),
    );
  }

  Widget _buildBody() {
    final match = _match!;
    final innings = List<dynamic>.from(match['innings'] ?? []);
    final result = calculateWinner(match);
    final mom = match['manOfTheMatch'] as String?;
    final date = DateTime.tryParse(match['date'] ?? '') ?? DateTime.now();

    return Column(
      children: [
        // ── Main tab bar: Scorecard | Match Info
        Container(
          color: Colors.white,
          child: Row(
            children: ['scorecard', 'info'].map((tab) {
              final isActive = _activeTab == tab;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _activeTab = tab),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(
                          color: isActive ? _primary : Colors.transparent, width: 3)),
                    ),
                    alignment: Alignment.center,
                    child: Text(tab == 'scorecard' ? 'Scorecard' : 'Match Info',
                        style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w800, fontSize: 14,
                            color: isActive ? _primary : Colors.grey)),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        Expanded(child: _activeTab == 'scorecard'
            ? _buildScorecard(match, innings, result, mom)
            : _buildMatchInfo(match, result, mom, date)),
      ],
    );
  }

  Widget _buildScorecard(Map<String, dynamic> match, List<dynamic> innings, String? result, String? mom) {
    if (innings.isEmpty) {
      return Center(child: Text('No innings data yet.', style: GoogleFonts.outfit(color: Colors.grey)));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Innings phase tabs
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('MATCH PHASES', style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w900, fontSize: 10, color: Colors.grey, letterSpacing: 1.5)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: List.generate(innings.length, (idx) {
                final inn = innings[idx] as Map<String, dynamic>;
                if (idx >= 2 && (inn['runs'] ?? 0) == 0 && (inn['wickets'] ?? 0) == 0 &&
                    (inn['batting'] as List? ?? []).isEmpty) return const SizedBox.shrink();
                final isSO = idx >= 2;
                final isActive = _activeInnings == idx;
                return GestureDetector(
                  onTap: () => setState(() => _activeInnings = idx),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isActive ? _primary : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isActive ? _primary : Colors.grey.shade200),
                      boxShadow: isActive ? [BoxShadow(color: _primary.withOpacity(0.3), blurRadius: 8)] : [],
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text((inn['team'] ?? '').toString().toUpperCase(),
                          style: GoogleFonts.outfit(color: isActive ? Colors.white : _primary,
                              fontWeight: FontWeight.w900, fontSize: 11)),
                      Text('${_ordinal(idx + 1)} Inn${isSO ? ' (SO)' : ''}',
                          style: GoogleFonts.outfit(color: isActive ? Colors.white70 : Colors.grey,
                              fontSize: 10, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text('${inn['runs']}/${inn['wickets']} (${inn['overs']}ov)',
                          style: GoogleFonts.outfit(color: isActive ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w900, fontSize: 12)),
                    ]),
                  ),
                );
              })),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Active innings header + target badge
        _buildInningsHeader(match, innings),
        const SizedBox(height: 16),

        // ── Batting table
        if ((innings[_activeInnings]['batting'] as List? ?? []).isNotEmpty) ...[
          _buildSectionTitle('Batting'),
          _buildBattingTable(List<dynamic>.from(innings[_activeInnings]['batting'] ?? [])),
          const SizedBox(height: 4),
          _buildExtrasRow(innings[_activeInnings]),
          _buildHitBreakdown(innings[_activeInnings]),
          const SizedBox(height: 16),
        ],

        // ── Bowling table (from opposing innings)
        ..._buildBowlingSection(innings),

        // ── Fall of Wickets
        if ((innings[_activeInnings]['fallOfWickets'] as List? ?? []).isNotEmpty) ...[
          _buildSectionTitle('Fall of Wickets'),
          _buildFoWTable(List<dynamic>.from(innings[_activeInnings]['fallOfWickets'])),
          const SizedBox(height: 16),
        ],

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildInningsHeader(Map<String, dynamic> match, List<dynamic> innings) {
    final inn = innings[_activeInnings] as Map<String, dynamic>;
    final isSecondInn = _activeInnings % 2 != 0 && _activeInnings > 0;
    final isSO = _activeInnings >= 2;
    final ovs = isSO ? 1 : (match['totalOvers'] as num? ?? 20).toInt();
    final target = (match['score']?['target'] as num?) ?? ((innings[_activeInnings - (isSecondInn ? 1 : 0)]['runs'] as num? ?? 0) + 1);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${(inn['team'] ?? '').toString().toUpperCase()} ${_ordinal(_activeInnings + 1)} INNINGS${isSO ? ' (Super Over)' : ''}',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 15, color: _primary)),
          Text(isSO ? 'Total 1 over' : 'Total ${match['totalOvers']} overs',
              style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
        ]),
        if (isSecondInn)
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('TARGET SCORE', style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(color: _danger, borderRadius: BorderRadius.circular(10)),
              child: Text('Target: $target (${ovs} ${pluralOvers(ovs)})',
                  style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
            ),
          ]),
      ],
    );
  }

  Widget _buildBattingTable(List<dynamic> batting) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      clipBehavior: Clip.hardEdge,
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(2.2),
          1: FlexColumnWidth(2),
          2: FlexColumnWidth(0.7),
          3: FlexColumnWidth(0.7),
          4: FlexColumnWidth(0.7),
          5: FlexColumnWidth(0.7),
          6: FlexColumnWidth(0.9),
        },
        children: [
          _tableHeader(['BATTER', 'STATUS', 'R', 'B', '4s', '6s', 'SR'], dark: true),
          ...batting.map((b) => _tableRow([
            toCamelCase(b['player']),
            toCamelCase(b['status'] ?? ''),
            '${b['runs'] ?? 0}',
            '${b['balls'] ?? 0}',
            '${b['fours'] ?? 0}',
            '${b['sixes'] ?? 0}',
            '${b['strikeRate'] ?? 0}',
          ], isFirst: true)),
        ],
      ),
    );
  }

  Widget _buildExtrasRow(Map<String, dynamic> inn) {
    final ext = inn['extras'] as Map<String, dynamic>? ?? {};
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        'Extras: ${ext['total'] ?? 0}  (wd ${ext['wides'] ?? 0}, nb ${ext['noBalls'] ?? 0}, b ${ext['byes'] ?? 0}, lb ${ext['legByes'] ?? 0})',
        style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildHitBreakdown(Map<String, dynamic> inn) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        'Dots:${inn['dots'] ?? 0}  1s:${inn['ones'] ?? 0}  2s:${inn['twos'] ?? 0}  3s:${inn['threes'] ?? 0}  4s:${inn['fours'] ?? 0}  6s:${inn['sixes'] ?? 0}',
        style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
      ),
    );
  }

  List<Widget> _buildBowlingSection(List<dynamic> innings) {
    final bowlInnIdx = _activeInnings.isEven ? _activeInnings + 1 : _activeInnings - 1;
    if (bowlInnIdx < 0 || bowlInnIdx >= innings.length) return [];
    final bowlInn = innings[bowlInnIdx] as Map<String, dynamic>;
    final bowling = List<dynamic>.from(bowlInn['bowling'] ?? []);
    if (bowling.isEmpty) return [];

    return [
      _buildSectionTitle('Bowling'),
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade100),
        ),
        clipBehavior: Clip.hardEdge,
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(2),
            1: FlexColumnWidth(0.7),
            2: FlexColumnWidth(0.7),
            3: FlexColumnWidth(0.7),
            4: FlexColumnWidth(0.7),
            5: FlexColumnWidth(0.7),
            6: FlexColumnWidth(0.7),
            7: FlexColumnWidth(0.9),
          },
          children: [
            _tableHeader(['BOWLER', 'O', 'M', 'R', 'W', 'WD', 'NB', 'ECO'], dark: false),
            ...bowling.map((b) => _tableRow([
              toCamelCase(b['player']),
              '${b['overs'] ?? 0}',
              '${b['maidens'] ?? 0}',
              '${b['runs'] ?? 0}',
              '${b['wickets'] ?? 0}',
              '${b['wides'] ?? 0}',
              '${b['noBalls'] ?? 0}',
              '${b['economy'] ?? 0}',
            ])),
          ],
        ),
      ),
      const SizedBox(height: 16),
    ];
  }

  Widget _buildFoWTable(List<dynamic> fow) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade100)),
      clipBehavior: Clip.hardEdge,
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(0.7),
          1: FlexColumnWidth(1),
          2: FlexColumnWidth(0.7),
          3: FlexColumnWidth(2),
        },
        children: [
          _tableHeader(['WKT', 'SCORE', 'OV', 'PLAYER'], dark: false),
          ...fow.map((f) => _tableRow(['${f['wicket']}', '${f['runs']}', '${f['overs']}', toCamelCase(f['player'])])),
        ],
      ),
    );
  }

  TableRow _tableHeader(List<String> cols, {bool dark = true}) {
    return TableRow(
      decoration: BoxDecoration(color: dark ? const Color(0xFF1E293B) : Colors.grey.shade700),
      children: cols.map((c) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        child: Text(c, style: GoogleFonts.outfit(
            color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10)),
      )).toList(),
    );
  }

  TableRow _tableRow(List<String> cells, {bool isFirst = false}) {
    return TableRow(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
      children: cells.indexed.map((e) {
        final isName = isFirst && e.$1 == 0;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          child: Text(e.$2,
              style: GoogleFonts.outfit(
                  fontWeight: isName ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 11,
                  color: Colors.black87),
              overflow: isName ? TextOverflow.ellipsis : TextOverflow.clip),
        );
      }).toList(),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title.toUpperCase(),
          style: GoogleFonts.outfit(
              fontWeight: FontWeight.w900, fontSize: 11,
              color: Colors.grey, letterSpacing: 1.5)),
    );
  }

  Widget _buildMatchInfo(Map<String, dynamic> match, String? result, String? mom, DateTime date) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      // Match header
      _infoCard('MATCH', [
        _infoRow('Teams', '${match['teamA']} vs ${match['teamB']}'),
        _infoRow('Series', match['series'] ?? 'SMCC LIVE'),
        _infoRow('Venue', match['venue'] ?? 'TBA'),
        _infoRow('Date', '${date.day}/${date.month}/${date.year}'),
        _infoRow('Time', formatTime(match['date'])),
        _infoRow('Format', '${match['totalOvers']} Overs'),
      ]),
      if (result != null) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _success.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _success.withOpacity(0.2)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('FINAL RESULT', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 10, color: _success, letterSpacing: 1)),
            const SizedBox(height: 6),
            Text(result, style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 15, color: _success)),
            if (mom != null && mom.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(children: [
                const Text('🥇 ', style: TextStyle(fontSize: 18)),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('MAN OF THE MATCH', style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: _primary, letterSpacing: 1)),
                  Text(mom.toUpperCase(), style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w900, color: _primary)),
                ]),
              ]),
            ],
          ]),
        ),
      ],
    ]);
  }

  Widget _infoCard(String title, List<Widget> rows) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 10, color: Colors.grey, letterSpacing: 1.5)),
        const SizedBox(height: 10),
        ...rows,
      ]),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
        Text(value, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w800)),
      ]),
    );
  }

  Widget _buildBoundaryOverlay() {
    final isSix = _blastValue == 6;
    return Positioned.fill(
      child: Container(
        color: Colors.white.withOpacity(0.75),
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 400),
            curve: Curves.elasticOut,
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: isSix
                    ? [const Color(0xFF059669), const Color(0xFF10B981)]
                    : [const Color(0xFFD97706), const Color(0xFFFBBF24)]),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: [const BoxShadow(color: Colors.black26, blurRadius: 20)],
              ),
              child: Text(isSix ? 'SIX!' : 'FOUR!',
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900)),
            ),
          ),
        ),
      ),
    );
  }
}
