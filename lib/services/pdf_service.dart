import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart';
import '../utils/calculations.dart';
import '../utils/formatters.dart';

class PdfService {
  static Future<void> generateScorecard(Map<String, dynamic> match) async {
    final doc = pw.Document();
    
    // Load logo if available
    pw.MemoryImage? logo;
    try {
      final logoData = await rootBundle.load('assets/logo.png');
      logo = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (_) {}

    final result = calculateWinner(match);
    final innings = List<dynamic>.from(match['innings'] ?? []);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          // Header
          if (logo != null)
            pw.Center(
              child: pw.Container(
                width: 60,
                height: 60,
                child: pw.Image(logo),
              ),
            ),
          pw.SizedBox(height: 10),
          
          if (result != null && match['status'] == 'completed')
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text('RESULT: ${result.toUpperCase()}',
                      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.green)),
                  pw.SizedBox(height: 4),
                  if (match['manOfTheMatch'] != null)
                    pw.Text('MAN OF THE MATCH: ${match['manOfTheMatch'].toUpperCase()}',
                        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.pink)),
                  pw.SizedBox(height: 10),
                ],
              ),
            ),

          pw.Center(
            child: pw.Text('SMCC CRICKET OFFICIAL SCORECARD',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
          ),
          pw.SizedBox(height: 6),
          pw.Center(
            child: pw.Text('${match['teamA'].toString().toUpperCase()} VS ${match['teamB'].toString().toUpperCase()}',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
          ),
          pw.SizedBox(height: 6),
          
          if (match['toss'] != null && match['toss']['winner'] != null)
            pw.Center(
              child: pw.Text(
                  'TOSS: ${match['toss']['winner'].toString().toUpperCase()} WON AND ELECTED TO ${match['toss']['decision'].toString().toUpperCase()} FIRST',
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
            ),
          pw.SizedBox(height: 6),
          
          pw.Center(
            child: pw.Text(
                'SERIES: ${(match['series'] ?? 'SMCC LIVE').toString().toUpperCase()} | GROUND: ${(match['venue'] ?? 'TBA').toString().toUpperCase()}',
                style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
          ),
          pw.SizedBox(height: 4),
          pw.Center(
            child: pw.Text(
                'DATE: ${formatDate(DateTime.parse(match['date']))} | EXPORTED: ${formatDate(DateTime.now())}',
                style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
          ),
          pw.SizedBox(height: 10),
          pw.Divider(thickness: 1, color: PdfColors.blue900),
          pw.SizedBox(height: 20),

          // Innings Data
          ...innings.asMap().entries.map((entry) {
            final idx = entry.key;
            final inn = entry.value;
            
            final bowlingInnIdx = idx % 2 == 0 ? idx + 1 : idx - 1;
            final bowlingInn = bowlingInnIdx < innings.length ? innings[bowlingInnIdx] : null;

            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  '${inn['team'].toString().toUpperCase()} ${_getOrdinal(idx + 1).toUpperCase()} INNINGS${idx >= 2 ? ' (SUPER OVER)' : ''}: ${inn['runs']}/${inn['wickets']} (${inn['overs']} OV)',
                  style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                ),
                pw.SizedBox(height: 10),
                
                // Batting Table
                if (inn['batting'] != null && (inn['batting'] as List).isNotEmpty)
                  pw.Table.fromTextArray(
                    context: context,
                    headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10),
                    cellStyle: const pw.TextStyle(fontSize: 9),
                    headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
                    data: [
                      ['Batter', 'Status', 'R', 'B', '4s', '6s', 'SR'],
                      ...(inn['batting'] as List).map((b) => [
                        b['player'].toString().toUpperCase(),
                        b['status'].toString().toUpperCase(),
                        b['runs'].toString(),
                        b['balls'].toString(),
                        b['fours'].toString(),
                        b['sixes'].toString(),
                        b['strikeRate'].toString(),
                      ]),
                      [
                        'EXTRAS',
                        '',
                        (inn['extras']?['total'] ?? 0).toString(),
                        '(WD: ${inn['extras']?['wides'] ?? 0}, NB: ${inn['extras']?['noBalls'] ?? 0}, B: ${inn['extras']?['byes'] ?? 0}, LB: ${inn['extras']?['legByes'] ?? 0})',
                        '',
                        '',
                        ''
                      ],
                    ],
                  ),
                pw.SizedBox(height: 10),

                // Hit Breakdown
                pw.Row(children: [
                   pw.Text('HIT BREAKDOWN: ', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                   pw.Text('DOTS: ${inn['dots'] ?? 0} | 1s: ${inn['ones'] ?? 0} | 2s: ${inn['twos'] ?? 0} | 3s: ${inn['threes'] ?? 0} | 4s: ${inn['fours'] ?? 0} | 6s: ${inn['sixes'] ?? 0}',
                      style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                ]),
                pw.SizedBox(height: 10),

                // Bowling Table
                if (bowlingInn != null && bowlingInn['bowling'] != null && (bowlingInn['bowling'] as List).isNotEmpty)
                  pw.Table.fromTextArray(
                    context: context,
                    headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10),
                    cellStyle: const pw.TextStyle(fontSize: 9),
                    headerDecoration: const pw.BoxDecoration(color: PdfColors.green900),
                    data: [
                      ['Bowler', 'O', 'M', 'R', 'W', 'WD', 'NB', 'Eco'],
                      ...(bowlingInn['bowling'] as List).map((b) => [
                        b['player'].toString().toUpperCase(),
                        b['overs'].toString(),
                        b['maidens'].toString(),
                        b['runs'].toString(),
                        b['wickets'].toString(),
                        (b['wides'] ?? 0).toString(),
                        (b['noBalls'] ?? 0).toString(),
                        b['economy'].toString(),
                      ]),
                    ],
                  ),
                pw.SizedBox(height: 10),

                // Fall of Wickets
                if (inn['fallOfWickets'] != null && (inn['fallOfWickets'] as List).isNotEmpty)
                   pw.Column(
                     crossAxisAlignment: pw.CrossAxisAlignment.start,
                     children: [
                        pw.Text('FALL OF WICKETS', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
                        pw.SizedBox(height: 4),
                        pw.Table.fromTextArray(
                          context: context,
                          cellStyle: const pw.TextStyle(fontSize: 8),
                          headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                          data: [
                            ['WKT', 'SCORE', 'OVER', 'PLAYER'],
                            ...(inn['fallOfWickets'] as List).map((f) => [
                              f['wicket'].toString(),
                              f['runs'].toString(),
                              f['overs'].toString(),
                              f['player'].toString().toUpperCase(),
                            ]),
                          ],
                        ),
                     ]
                   ),
                pw.SizedBox(height: 10),

                // Did Not Bat
                if (true) // Logic to filter squad
                   pw.Row(children: [
                      pw.Text('DID NOT BAT: ', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                      pw.Expanded(child: pw.Text(_getYetToBat(match, inn), style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600))),
                   ]),

                pw.SizedBox(height: 20),
                if (idx < innings.length - 1) pw.Divider(thickness: 0.5, color: PdfColors.grey400),
                pw.SizedBox(height: 20),
              ],
            );
          }).toList(),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save());
  }

  static String _getYetToBat(Map<String, dynamic> match, Map<String, dynamic> innings) {
    final teamName = innings['team'];
    final squad = List<dynamic>.from(teamName == match['teamA'] ? (match['teamASquad'] ?? []) : (match['teamBSquad'] ?? []));
    if (squad.isEmpty) return 'N/A';
    
    final battedPlayers = (innings['batting'] as List?)?.map((b) => b['player'].toString().trim().toLowerCase()).toList() ?? [];
    final yetToBat = squad.where((p) => p != null && p.toString().trim().isNotEmpty && !battedPlayers.contains(p.toString().trim().toLowerCase())).map((p) => p.toString().toUpperCase()).toList();
    
    return yetToBat.isEmpty ? 'NONE' : yetToBat.join(', ');
  }

  static String _getOrdinal(int n) {
    if (n >= 11 && n <= 13) return '${n}th';
    switch (n % 10) {
      case 1: return '${n}st';
      case 2: return '${n}nd';
      case 3: return '${n}rd';
      default: return '${n}th';
    }
  }
}
