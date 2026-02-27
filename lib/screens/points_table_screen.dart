/// points_table_screen.dart — Full port of smcc-web/src/pages/PointsTable.jsx
/// Real-time points table with NRR calculation (ball-accuracy), series filter, socket updates.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../services/api_service.dart';
import '../utils/calculations.dart';

class PointsTableScreen extends StatefulWidget {
  const PointsTableScreen({Key? key}) : super(key: key);

  @override
  State<PointsTableScreen> createState() => _PointsTableScreenState();
}

class _PointsTableScreenState extends State<PointsTableScreen> {
  List<dynamic> _matches = [];
  bool _loading = true;
  String? _activeSeries;

  late io.Socket _socket;

  static const Color _primary = Color(0xFF2563EB);

  @override
  void initState() {
    super.initState();
    _fetch();
    _socket = io.io(ApiService.socketUrl, <String, dynamic>{'transports': ['websocket']});
    _socket.on('matchUpdate', (_) => _fetch());
    _socket.on('matchDeleted', (_) => _fetch());
  }

  @override
  void dispose() {
    _socket.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    try {
      final data = await ApiService.getMatches();
      setState(() {
        _matches = data;
        _loading = false;
        if (_activeSeries == null && data.isNotEmpty) {
          final series = data.map((m) => (m['series'] ?? 'SMCC LIVE').toString()).toSet().toList();
          _activeSeries = series.first;
        }
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final seriesList = _matches.map((m) => (m['series'] ?? 'SMCC LIVE').toString()).toSet().toList();
    final filtered = _activeSeries == null
        ? _matches
        : _matches.where((m) => (m['series'] ?? 'SMCC LIVE').toString() == _activeSeries).toList();
    final stats = calculateStats(filtered);

    return _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _fetch,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Series Standings',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 20,
                        textStyle: const TextStyle(letterSpacing: 0.5))),
                const SizedBox(height: 12),

                // Series filter tabs
                if (seriesList.length > 1) ...[
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: seriesList.map((s) {
                        final isActive = s == _activeSeries;
                        return GestureDetector(
                          onTap: () => setState(() => _activeSeries = s),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isActive ? _primary : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: isActive ? _primary : Colors.grey.shade300),
                            ),
                            child: Text(s, style: GoogleFonts.outfit(
                                color: isActive ? Colors.white : Colors.grey.shade700,
                                fontWeight: FontWeight.w800, fontSize: 13)),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Points Table card
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade100),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        color: Colors.grey.shade50,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${_activeSeries ?? ''} • Points Table',
                                style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 10, color: Colors.grey, letterSpacing: 1)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(20)),
                              child: Text('REAL-TIME', style: GoogleFonts.outfit(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
                            ),
                          ],
                        ),
                      ),
                      // Table header
                      _buildTableHeader(),
                      // Rows
                      if (stats.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text('No matches played in this series yet.',
                              style: GoogleFonts.outfit(color: Colors.grey)),
                        )
                      else
                        ...stats.asMap().entries.map((e) => _buildTeamRow(e.value, e.key)),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // NRR explanation
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: Colors.white, borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade100)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('NRR RULES & CALCULATION',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1)),
                    const SizedBox(height: 6),
                    Text(
                      'Net Run Rate (NRR) is calculated by taking the average runs per over scored across the tournament, minus the average runs per over conceded.\n\nFormula: (Total Runs Scored / Total Overs Faced) - (Total Runs Conceded / Total Overs Bowled)',
                      style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey.shade700, height: 1.5),
                    ),
                  ]),
                ),
              ],
            ),
          );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
      child: Row(children: [
        Expanded(flex: 4, child: Text('TEAMS', style: _hStyle())),
        _hCell('M'),
        _hCell('W'),
        _hCell('L'),
        _hCell('T/NR'),
        _hCell('PTS'),
        _hCell('NRR'),
      ]),
    );
  }

  Widget _hCell(String t) => Expanded(flex: 2, child: Center(child: Text(t, style: _hStyle())));
  TextStyle _hStyle() => GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 10, color: Colors.grey, letterSpacing: 1);

  Widget _buildTeamRow(Map<String, dynamic> team, int idx) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: idx == 0 ? _primary.withOpacity(0.04) : Colors.transparent,
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(children: [
        Expanded(flex: 4, child: Row(children: [
          Text('${idx + 1} ', style: GoogleFonts.outfit(color: Colors.grey, fontWeight: FontWeight.w700, fontSize: 12)),
          Expanded(child: Text((team['name'] ?? '').toString().toUpperCase(),
              style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13))),
        ])),
        _cell('${team['p']}'),
        _cell('${team['w']}', color: Colors.green.shade700),
        _cell('${team['l']}', color: Colors.red.shade600),
        _cell('${team['d']}', color: Colors.grey),
        _cell('${team['pts']}', color: _primary, bold: true, large: true),
        _cell('${team['nrr']}', color: Colors.grey.shade700),
      ]),
    );
  }

  Widget _cell(String t, {Color? color, bool bold = false, bool large = false}) {
    return Expanded(flex: 2, child: Center(
      child: Text(t, style: GoogleFonts.outfit(
          color: color ?? Colors.black87,
          fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
          fontSize: large ? 15 : 12)),
    ));
  }
}
