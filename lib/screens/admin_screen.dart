/// admin_screen.dart — Mobile Admin Console
/// Real credentials login via POST /api/auth/login with platform: 'mobile'
/// Cross-platform single-session: listens for adminForceLogout socket event.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../services/api_service.dart';
import '../utils/formatters.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({Key? key}) : super(key: key);

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  // ── Auth state ─────────────────────────────────────────────────────────────
  bool _loggedIn = false;
  String? _token;
  int? _userId;
  bool _authLoading = true;   // checking saved session on mount
  bool _loginLoading = false;
  String _loginError = '';

  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;

  // ── Matches / Scoring state ────────────────────────────────────────────────
  List<dynamic> _matches = [];
  bool _matchesLoading = false;
  Map<String, dynamic>? _selected;

  int _runs = 0;
  bool _isWicket = false;
  String _extra = 'none';

  // ── Socket ─────────────────────────────────────────────────────────────────
  late io.Socket _socket;

  // ── Theme ──────────────────────────────────────────────────────────────────
  static const Color _primary = Color(0xFF2563EB);
  static const Color _danger  = Color(0xFFDC2626);
  static const Color _success = Color(0xFF059669);

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _restoreSession();
    _connectSocket();
  }

  @override
  void dispose() {
    _socket.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ── Session restore from SharedPreferences ─────────────────────────────────
  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('admin_token');
    final userId = prefs.getInt('admin_user_id');
    if (token != null && userId != null) {
      // Verify token is still valid on the server
      final ok = await _verifyToken(token);
      if (ok) {
        setState(() { _token = token; _userId = userId; _loggedIn = true; });
        await _fetchMatches();
      } else {
        await prefs.remove('admin_token');
        await prefs.remove('admin_user_id');
      }
    }
    setState(() => _authLoading = false);
  }

  Future<bool> _verifyToken(String token) async {
    try {
      final resp = await http.get(
        Uri.parse('${ApiService.baseUrl}/auth/verify'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 8));
      return resp.statusCode == 200;
    } catch (_) {
      return false; // network error — allow offline cached session to stand
    }
  }

  // ── Socket (force-logout listener) ────────────────────────────────────────
  void _connectSocket() {
    _socket = io.io(ApiService.socketUrl, <String, dynamic>{
      'transports': ['websocket'], 'autoConnect': true,
    });

    _socket.on('adminForceLogout', (data) {
      final platform = data is Map ? data['platform'] : null;
      if (platform == 'mobile' || platform == 'all') {
        _forceLogout(reason: '⚡ Your session was taken over by Web. Please log in again.');
      }
    });

    _socket.on('adminSessionExpired', (_) {
      _forceLogout(reason: '⏱ Admin session expired. Please log in again.');
    });

    _socket.on('adminSessionEnded', (_) {
      if (_loggedIn) _forceLogout(reason: 'Admin session ended.');
    });
  }

  void _forceLogout({required String reason}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('admin_token');
    await prefs.remove('admin_user_id');
    if (mounted) {
      setState(() { _loggedIn = false; _token = null; _userId = null; _selected = null; _matches = []; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(reason, style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        backgroundColor: _danger, duration: const Duration(seconds: 6),
      ));
    }
  }

  // ── Login ─────────────────────────────────────────────────────────────────
  Future<void> _login() async {
    setState(() { _loginLoading = true; _loginError = ''; });
    try {
      final resp = await http.post(
        Uri.parse('${ApiService.baseUrl}/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': _usernameCtrl.text.trim(),
          'password': _passwordCtrl.text,
          'platform': 'mobile',
        }),
      ).timeout(const Duration(seconds: 15));

      final body = json.decode(resp.body);
      if (resp.statusCode == 200) {
        final token = body['token'] as String;
        final userId = (body['user']['id'] as num).toInt();
        final role = body['user']['role'] as String;

        if (role != 'admin') {
          setState(() { _loginError = 'Access denied. Admin credentials required.'; _loginLoading = false; });
          return;
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('admin_token', token);
        await prefs.setInt('admin_user_id', userId);

        setState(() { _token = token; _userId = userId; _loggedIn = true; _loginLoading = false; });
        await _fetchMatches();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('✅ Logged in as Admin (Mobile)', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
            backgroundColor: _success, duration: const Duration(seconds: 2),
          ));
        }
      } else {
        setState(() { _loginError = body['msg'] ?? 'Login failed. Check your credentials.'; _loginLoading = false; });
      }
    } catch (e) {
      setState(() { _loginError = 'Connection error. Try again.'; _loginLoading = false; });
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────
  Future<void> _logout() async {
    try {
      await http.post(
        Uri.parse('${ApiService.baseUrl}/auth/logout'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'userId': _userId}),
      ).timeout(const Duration(seconds: 8));
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('admin_token');
    await prefs.remove('admin_user_id');
    setState(() { _loggedIn = false; _token = null; _userId = null; _selected = null; _matches = []; });
  }

  // ── Data ──────────────────────────────────────────────────────────────────
  Map<String, String> get _authHeaders => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $_token',
    'x-auth-token': _token ?? '',
  };

  Future<void> _fetchMatches() async {
    setState(() => _matchesLoading = true);
    try {
      final data = await ApiService.getMatches();
      setState(() { _matches = data; _matchesLoading = false; });
    } catch (_) {
      setState(() => _matchesLoading = false);
    }
  }

  Future<void> _selectMatch(Map<String, dynamic> match) async {
    try {
      final fresh = await ApiService.getMatch((match['_id'] ?? match['id']).toString());
      setState(() { _selected = fresh; _runs = 0; _isWicket = false; _extra = 'none'; });
    } catch (_) {}
  }

  Future<void> _addBall() async {
    if (_selected == null || _token == null) return;
    final id = (_selected!['_id'] ?? _selected!['id']).toString();
    try {
      final resp = await http.put(
        Uri.parse('${ApiService.baseUrl}/matches/$id'),
        headers: _authHeaders,
        body: json.encode({
          'ball': {'runs': _runs, 'isWicket': _isWicket, 'extra': _extra == 'none' ? null : _extra}
        }),
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        setState(() {
          _selected = json.decode(resp.body);
          _runs = 0; _isWicket = false; _extra = 'none';
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Ball added!', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
          backgroundColor: _success, duration: const Duration(seconds: 1),
        ));
      } else if (resp.statusCode == 401) {
        _forceLogout(reason: 'Session expired. Please log in again.');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'), backgroundColor: _danger));
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_authLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Row(children: [
          const Icon(Icons.terminal, color: _danger, size: 20),
          const SizedBox(width: 8),
          Text('Console', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
          if (_loggedIn) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: _success.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
              child: Text('ADMIN • MOBILE', style: GoogleFonts.outfit(color: _success, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
            ),
          ],
        ]),
        actions: [
          if (_loggedIn)
            TextButton(
              onPressed: _logout,
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
            child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 20),
          Text('Admin Console', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 24)),
          const SizedBox(height: 4),
          Text('Single session enforced across Web & Mobile',
              style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12), textAlign: TextAlign.center),
          const SizedBox(height: 28),

          if (_loginError.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: _danger.withOpacity(0.1), borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _danger.withOpacity(0.3))),
              child: Text(_loginError, style: GoogleFonts.outfit(color: _danger, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 12),
          ],

          TextField(
            controller: _usernameCtrl,
            decoration: InputDecoration(
              labelText: 'Username', prefixIcon: const Icon(Icons.person_outline),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)), filled: true, fillColor: Colors.white,
            ),
            onSubmitted: (_) => _login(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordCtrl,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)), filled: true, fillColor: Colors.white,
            ),
            onSubmitted: (_) => _login(),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: _primary, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              onPressed: _loginLoading ? null : _login,
              child: _loginLoading
                  ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                  : Text('SIGN IN', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 2)),
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
    return _matchesLoading
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
    final runs = score['runs'] ?? 0;
    final wickets = score['wickets'] ?? 0;
    final overs = score['overs'] ?? 0;
    final battingTeam = score['battingTeam'] ?? '';

    return Column(children: [
      // Back header
      Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          GestureDetector(
            onTap: () => setState(() => _selected = null),
            child: Row(children: [
              const Icon(Icons.arrow_back_ios, size: 16, color: Colors.grey),
              Text('  Matches', style: GoogleFonts.outfit(color: Colors.grey, fontWeight: FontWeight.w700)),
            ]),
          ),
          const Spacer(),
          Flexible(child: Text(
              '${(match['teamA'] ?? '').toString().toUpperCase()} vs ${(match['teamB'] ?? '').toString().toUpperCase()}',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13), overflow: TextOverflow.ellipsis)),
        ]),
      ),

      Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
        // Score display
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(children: [
            Text(battingTeam.toUpperCase(),
                style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
            const SizedBox(height: 4),
            Text('$runs/$wickets', style: GoogleFonts.outfit(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900)),
            Text('$overs overs', style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
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

        // Run buttons
        _sectionLabel('RUNS'),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [0, 1, 2, 3, 4, 5, 6].map((r) {
          Color color = Colors.white;
          Color textColor = Colors.black87;
          if (r == 4) { color = _success; textColor = Colors.white; }
          if (r == 6) { color = _primary; textColor = Colors.white; }
          final isSelected = _runs == r;
          return GestureDetector(
            onTap: () => setState(() => _runs = r),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 60, height: 60,
              decoration: BoxDecoration(
                color: isSelected ? _primary : color,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isSelected ? _primary : Colors.grey.shade200, width: 2),
                boxShadow: isSelected ? [BoxShadow(color: _primary.withOpacity(0.3), blurRadius: 10)] : [],
              ),
              alignment: Alignment.center,
              child: Text('$r', style: GoogleFonts.outfit(
                  color: isSelected ? Colors.white : textColor, fontWeight: FontWeight.w900, fontSize: 20)),
            ),
          );
        }).toList()),
        const SizedBox(height: 18),

        // Extra toggles
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

        // Wicket toggle
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: _isWicket ? _danger.withOpacity(0.08) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _isWicket ? _danger : Colors.grey.shade200, width: 2),
          ),
          child: CheckboxListTile(
            activeColor: _danger,
            title: Text('WICKET', style: GoogleFonts.outfit(
                fontWeight: FontWeight.w900, color: _isWicket ? _danger : Colors.black87, letterSpacing: 1)),
            value: _isWicket,
            onChanged: (v) => setState(() => _isWicket = v!),
          ),
        ),
        const SizedBox(height: 20),

        // Submit
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            icon: const Icon(Icons.sports_cricket),
            label: Text(
                'ADD BALL  •  $_runs runs${_extra != 'none' ? ' (${_extra == 'noBall' ? 'No Ball' : _extra == 'legBye' ? 'Leg Bye' : _extra})' : ''}${_isWicket ? ' + WICKET 🔴' : ''}',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14)),
            onPressed: _addBall,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.refresh),
            label: Text('Refresh Score', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
            onPressed: () => _selectMatch(match),
          ),
        ),
      ]))),
    ]);
  }

  Widget _sectionLabel(String t) => Align(
    alignment: Alignment.centerLeft,
    child: Text(t, style: GoogleFonts.outfit(
        fontWeight: FontWeight.w900, fontSize: 10, color: Colors.grey.shade600, letterSpacing: 1.5)),
  );
}
