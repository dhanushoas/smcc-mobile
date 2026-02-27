/// schedule_screen.dart — Full port of smcc-web/src/pages/Schedule.jsx
/// Shows upcoming matches only with venue, date, time, overs format.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../utils/formatters.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({Key? key}) : super(key: key);

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  List<dynamic> _matches = [];
  bool _loading = true;

  static const Color _primary = Color(0xFF2563EB);

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final data = await ApiService.getMatches();
      setState(() {
        _matches = (data as List).where((m) => m['status'] == 'upcoming').toList();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _fetch,
            child: _matches.isEmpty
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.calendar_today_outlined, size: 56, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text('No upcoming matches scheduled.',
                          style: GoogleFonts.outfit(color: Colors.grey, fontSize: 15)),
                      Text('Stay tuned for updates!',
                          style: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 12)),
                    ]),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _matches.length + 1,
                    itemBuilder: (_, i) {
                      if (i == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
                            Text('Upcoming Schedule',
                                style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 22,
                                    color: _primary), textAlign: TextAlign.center),
                            const SizedBox(height: 4),
                            Text("Don't miss out on the action. Mark your calendars!",
                                style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12),
                                textAlign: TextAlign.center),
                          ]),
                        );
                      }
                      return _buildCard(_matches[i - 1]);
                    },
                  ),
          );
  }

  Widget _buildCard(Map<String, dynamic> match) {
    final date = DateTime.tryParse(match['date'] ?? '') ?? DateTime.now();
    final dateStr = formatDate(date.toLocal());
    final timeStr = formatTime(match['date']);
    final series = (match['series'] ?? 'SMCC LIVE').toString();
    final venue = (match['venue'] ?? '').toString();
    final teamA = (match['teamA'] ?? 'Team A').toString().toUpperCase();
    final teamB = (match['teamB'] ?? 'Team B').toString().toUpperCase();
    final overs = match['totalOvers'] ?? 20;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          // Series header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(color: _primary.withOpacity(0.08)),
            child: Column(children: [
              Text(series, style: GoogleFonts.outfit(color: _primary, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
              if (venue.isNotEmpty) ...[
                const SizedBox(height: 2),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.location_on, size: 12, color: Colors.grey.shade600),
                  const SizedBox(width: 3),
                  Text(venue, style: GoogleFonts.outfit(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ],
            ]),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Teams vs
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(teamA, textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 17))),
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: _primary, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: Text('VS', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11)),
                    ),
                    Expanded(child: Text(teamB, textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 17))),
                  ],
                ),
                const SizedBox(height: 16),

                // Date & Time info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: Column(children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('DATE', style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w700)),
                      Text(dateStr, style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13)),
                    ]),
                    const SizedBox(height: 6),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('TIME', style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w700)),
                      Text(timeStr, style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13)),
                    ]),
                  ]),
                ),
              ],
            ),
          ),

          // Overs format footer
          Container(
            width: double.infinity,
            color: const Color(0xFF1E293B),
            padding: const EdgeInsets.symmetric(vertical: 8),
            alignment: Alignment.center,
            child: Text('$overs OVERS FORMAT',
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 2)),
          ),
        ],
      ),
    );
  }
}
