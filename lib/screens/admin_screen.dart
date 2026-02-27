/// admin_screen.dart — Mobile admin console mirroring smcc-web AdminDashboard.jsx
/// Access-code protected entry, then provides live scoring controls via the API.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import '../utils/formatters.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({Key? key}) : super(key: key);

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  // ── Static access code (change to match your secret) ─────────────────────
  static const String _accessCode = 'SMCC2024';

  bool _loggedIn = false;
  final _codeCtrl = TextEditingController();
  String _codeError = '';

  // ── Matches state ─────────────────────────────────────────────────────────
  List<dynamic> _matches = [];
  bool _loading = false;
  Map<String, dynamic>? _selected;

  // ── Scoring state ─────────────────────────────────────────────────────────
  int _runs = 0;
  bool _isWicket = false;
  String _extra = 'none'; // none | wide | noBall | bye | legBye

  // ── Theme ──────────────────────────────────────────────────────────────────
  static const Color _primary = Color(0xFF2563EB);
  static const Color _danger  = Color(0xFFDC2626);
  static const Color _success = Color(0xFF059669);

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  // ── Auth ─────────────────────────────────────────────────────────────────
  void _login() {
    if (_codeCtrl.text.trim().toUpperCase() == _accessCode) {
      setState(() { _loggedIn = true; _codeError = ''; });
      _fetchMatches();
    } else {
      setState(() => _codeError = 'Invalid access code. Please try again.');
    }
  }

  // ── Data ─────────────────────────────────────────────────────────────────
  Future<void> _fetchMatches() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.getMatches();
      setState(() { _matches = data; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _selectMatch(Map<String, dynamic> match) async {
    try {
      final fresh = await ApiService.getMatch((match['_id'] ?? match['id']).toString());
      setState(() { _selected = fresh; _runs = 0; _isWicket = false; _extra = 'none'; });
    } catch (_) {}
  }

  Future<void> _update(Map<String, dynamic> patch) async {
    final id = (_selected!['_id'] ?? _selected!['id']).toString();
    try {
      final resp = await http.put(
        Uri.parse('${ApiService.baseUrl}/matches/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(patch),
      ).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final updated = json.decode(resp.body);
        setState(() => _selected = updated);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Updated!', style: GoogleFonts.outfit()), backgroundColor: _success, duration: const Duration(seconds: 1)));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e', style: GoogleFonts.outfit()), backgroundColor: _danger));
    }
  }

  /// Mirrors AdminDashboard.jsx addBall — sends a ball event to the backend
  Future<void> _addBall() async {
    if (_selected == null) return;
    final score = Map<String, dynamic>.from(_selected!['score'] ?? {});
    final isExtra = _extra == 'wide' || _extra == 'noBall';
    final runsToAdd = _runs + (_extra == 'none' ? 0 : (_extra == 'wide' || _extra == 'noBall' ? 1 : 0));

    final patch = {
      'ball': {
        'runs': _runs,
        'isWicket': _isWicket,
        'extra': _extra == 'none' ? null : _extra,
      }
    };
    await _update(patch);
    setState(() { _runs = 0; _isWicket = false; _extra = 'none'; });
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Row(children: [
          const Icon(Icons.admin_panel_settings, color: _danger, size: 20),
          const SizedBox(width: 8),
          Text('Admin Console', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
        ]),
        actions: [
          if (_loggedIn)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: _fetchMatches,
            ),
          if (_loggedIn)
            TextButton(
              onPressed: () => setState(() { _loggedIn = false; _selected = null; _matches = []; }),
              child: Text('Logout', style: GoogleFonts.outfit(color: _danger, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: _loggedIn ? _buildDashboard() : _buildLoginGate(),
    );
  }

  // ── Login Gate ────────────────────────────────────────────────────────────
  Widget _buildLoginGate() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: _primary, shape: BoxShape.circle),
            child: const Icon(Icons.lock, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 20),
          Text('Admin Access', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 24)),
          const SizedBox(height: 6),
          Text('Enter your access code to continue', style: GoogleFonts.outfit(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 28),
          TextField(
            controller: _codeCtrl,
            obscureText: true,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 18, letterSpacing: 4),
            decoration: InputDecoration(
              hintText: '• • • • • • • •',
              errorText: _codeError.isEmpty ? null : _codeError,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              filled: true, fillColor: Colors.white,
            ),
            onSubmitted: (_) => _login(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              onPressed: _login,
              child: Text('LOGIN', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 2)),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Dashboard ─────────────────────────────────────────────────────────────
  Widget _buildDashboard() {
    if (_selected != null) return _buildScoringPanel();
    return _buildMatchList();
  }

  Widget _buildMatchList() {
    return _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _fetchMatches,
            child: _matches.isEmpty
                ? Center(child: Text('No matches found.', style: GoogleFonts.outfit(color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _matches.length,
                    itemBuilder: (_, i) => _buildMatchTile(_matches[i]),
                  ),
          );
  }

  Widget _buildMatchTile(Map<String, dynamic> match) {
    final status = (match['status'] ?? '').toString();
    Color statusColor = Colors.grey;
    if (status == 'live') statusColor = _danger;
    if (status == 'completed') statusColor = _success;
    if (status == 'upcoming') statusColor = _primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        onTap: () => _selectMatch(match),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        title: Text(
          '${(match['teamA'] ?? '').toString().toUpperCase()} vs ${(match['teamB'] ?? '').toString().toUpperCase()}',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 3),
          Text(match['series'] ?? 'SMCC LIVE', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey)),
          Text('${match['venue'] ?? ''} • ${formatTime(match['date'])}',
              style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey.shade500)),
        ]),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
          child: Text(status.toUpperCase(),
              style: GoogleFonts.outfit(color: statusColor, fontWeight: FontWeight.w900, fontSize: 10)),
        ),
      ),
    );
  }

  // ── Scoring Panel ─────────────────────────────────────────────────────────
  Widget _buildScoringPanel() {
    final match = _selected!;
    final score = match['score'] as Map<String, dynamic>? ?? {};
    final innings = List<dynamic>.from(match['innings'] ?? []);
    final runs = score['runs'] ?? 0;
    final wickets = score['wickets'] ?? 0;
    final overs = score['overs'] ?? 0;
    final battingTeam = score['battingTeam'] ?? '';

    return Column(
      children: [
        // Back bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            GestureDetector(
              onTap: () => setState(() => _selected = null),
              child: Row(children: [
                const Icon(Icons.arrow_back_ios, size: 16, color: Colors.grey),
                Text('  All Matches', style: GoogleFonts.outfit(color: Colors.grey, fontWeight: FontWeight.w700)),
              ]),
            ),
            const Spacer(),
            Text('${(match['teamA'] ?? '').toString().toUpperCase()} vs ${(match['teamB'] ?? '').toString().toUpperCase()}',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13)),
          ]),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              // ── Score display
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [_primary, const Color(0xFF1D4ED8)]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(children: [
                  Text(battingTeam.toUpperCase(),
                      style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Text('$runs/$wickets', style: GoogleFonts.outfit(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900)),
                  Text('$overs overs', style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
                  // Current over balls
                  if ((score['thisOver'] as List? ?? []).isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      ...(score['thisOver'] as List).map((b) {
                        final bs = b.toString().toUpperCase();
                        Color bg = Colors.white24;
                        if (bs == '6') bg = Colors.green;
                        if (bs == '4') bg = Colors.amber;
                        if (bs == 'W') bg = Colors.red;
                        return Container(
                          margin: const EdgeInsets.only(right: 6), width: 26, height: 26,
                          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(13)),
                          alignment: Alignment.center,
                          child: Text(b.toString(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                        );
                      }),
                    ]),
                  ],
                ]),
              ),
              const SizedBox(height: 20),

              // ── Run buttons
              _sectionLabel('RUNS'),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [0, 1, 2, 3, 4, 5, 6].map((r) {
                Color color = Colors.white;
                Color textColor = Colors.black87;
                if (r == 4) { color = _success; textColor = Colors.white; }
                if (r == 6) { color = _primary; textColor = Colors.white; }
                return GestureDetector(
                  onTap: () => setState(() => _runs = r),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 60, height: 60,
                    decoration: BoxDecoration(
                      color: _runs == r ? (_primary) : color,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _runs == r ? _primary : Colors.grey.shade200, width: 2),
                      boxShadow: _runs == r ? [BoxShadow(color: _primary.withOpacity(0.3), blurRadius: 10)] : [],
                    ),
                    alignment: Alignment.center,
                    child: Text('$r', style: GoogleFonts.outfit(
                        color: _runs == r ? Colors.white : textColor,
                        fontWeight: FontWeight.w900, fontSize: 20)),
                  ),
                );
              }).toList()),
              const SizedBox(height: 18),

              // ── Extra toggles
              _sectionLabel('EXTRA'),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: ['none', 'wide', 'noBall', 'bye', 'legBye'].map((ex) {
                final isActive = _extra == ex;
                final label = ex == 'none' ? 'None' : ex == 'noBall' ? 'No Ball' : ex == 'legBye' ? 'Leg Bye' : ex[0].toUpperCase() + ex.substring(1);
                return GestureDetector(
                  onTap: () => setState(() => _extra = ex),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isActive ? Colors.orange : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isActive ? Colors.orange : Colors.grey.shade200, width: 2),
                    ),
                    child: Text(label, style: GoogleFonts.outfit(
                        color: isActive ? Colors.white : Colors.black87, fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                );
              }).toList()),
              const SizedBox(height: 18),

              // ── Wicket toggle
              Row(children: [
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: _isWicket ? _danger : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _isWicket ? _danger : Colors.grey.shade200, width: 2),
                    ),
                    child: CheckboxListTile(
                      activeColor: _danger,
                      title: Text('WICKET', style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w900, color: _isWicket ? Colors.white : _danger, letterSpacing: 1)),
                      value: _isWicket,
                      onChanged: (v) => setState(() => _isWicket = v!),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 20),

              // ── Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.sports_cricket),
                  label: Text('ADD BALL  •  $_runs runs ${_extra != 'none' ? '(${_extra})' : ''} ${_isWicket ? '+ WICKET 🔴' : ''}',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 15)),
                  onPressed: _addBall,
                ),
              ),

              const SizedBox(height: 12),
              // Refresh score
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: Text('Refresh Score', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                  onPressed: () => _selectMatch(match),
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String t) => Align(
    alignment: Alignment.centerLeft,
    child: Text(t, style: GoogleFonts.outfit(
        fontWeight: FontWeight.w900, fontSize: 10, color: Colors.grey.shade600, letterSpacing: 1.5)),
  );
}
