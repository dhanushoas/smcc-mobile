import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../scorecard_screen.dart';

class TournamentDetailScreen extends StatefulWidget {
  final int tournamentId;
  const TournamentDetailScreen({super.key, required this.tournamentId});

  @override
  State<TournamentDetailScreen> createState() => _TournamentDetailScreenState();
}

class _TournamentDetailScreenState extends State<TournamentDetailScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _tournament;
  List<dynamic> _pointsTable = [];
  bool _isLoading = true;
  bool _isAdmin = false;
  late TabController _tabController;

  static const Color _primary = Color(0xFF032333);
  static const Color _accent = Color(0xFFFBBF24);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _checkAdmin();
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkAdmin() async {
    final isAdmin = await AuthService.isAdmin();
    if (mounted) setState(() => _isAdmin = isAdmin);
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      final t = await ApiService.getTournament(widget.tournamentId);
      final p = await ApiService.getPointsTable(widget.tournamentId);
      if (mounted) setState(() { _tournament = t; _pointsTable = p; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _runAction(Future<void> Function() action, String msg) async {
    setState(() => _isLoading = true);
    try {
      await action();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.green, content: Text(msg, style: GoogleFonts.outfit(fontWeight: FontWeight.bold))));
      _loadAll();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.red, content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}', style: GoogleFonts.outfit())));
      setState(() => _isLoading = false);
    }
  }

  String _titleCase(String s) => s.split(' ').map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}' : '').join(' ');

  String _fmtDate(String? d) {
    if (d == null) return 'TBD';
    final dt = DateTime.tryParse(d);
    if (dt == null) return 'TBD';
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '$h:$m $ampm • ${months[dt.month - 1]} ${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _tournament == null) return const Scaffold(backgroundColor: Color(0xFFF8FAFC), body: Center(child: CircularProgressIndicator()));
    if (_tournament == null) return Scaffold(body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Text('Tournament not found'), TextButton(onPressed: () => Navigator.pop(context), child: const Text('Back'))])));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(_tournament!['name'] ?? 'Tournament', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16)),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 11),
          unselectedLabelColor: Colors.white54,
          labelColor: Colors.white,
          indicatorColor: _accent,
          tabs: const [
            Tab(text: 'INFO'),
            Tab(text: 'TEAMS'),
            Tab(text: 'SCHEDULE'),
            Tab(text: 'STANDINGS'),
            Tab(text: 'BRACKET'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildInfoTab(),
          _buildTeamsTab(),
          _buildScheduleTab(),
          _buildStandingsTab(),
          _buildBracketTab(),
        ],
      ),
    );
  }

  // ── INFO TAB ─────────────────────────────────────────────────────────────────
  Widget _buildInfoTab() {
    final t = _tournament!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tournament header card
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: _primary, borderRadius: BorderRadius.circular(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (t['type'] != null) Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(20)), child: Text(t['type'].toString().replaceAll('_', ' ').toUpperCase(), style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black))),
                    const SizedBox(width: 8),
                    if (t['ballType'] != null) Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(20)), child: Text('${t['ballType'].toString().toUpperCase()} BALL', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white))),
                  ],
                ),
                const SizedBox(height: 12),
                Text(t['name']?.toString().toUpperCase() ?? '', style: GoogleFonts.outfit(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 16),
                _infoRow(Icons.location_on, _titleCase(t['venue'] ?? 'TBD')),
                _infoRow(Icons.business, t['organizer'] ?? 'SMCC'),
                _infoRow(Icons.sports_cricket, '${t['settings']?['oversPerMatch'] ?? 20} Overs'),
                _infoRow(Icons.people, '${(t['teams'] as List?)?.length ?? 0} / ${t['totalTeams']} Teams'),
                if (t['startDate'] != null) _infoRow(Icons.calendar_today, _fmtDate(t['startDate'])),
                if (t['matchGapMinutes'] != null) _infoRow(Icons.timer, '${t['matchGapMinutes']} min gap between matches'),
              ],
            ),
          ),

          // Admin controls
          if (_isAdmin) ...[
            Text('ADMIN CONTROLS', style: GoogleFonts.outfit(color: _primary, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _actionBtn('Register Team', Icons.add, () => _showRegisterDialog()),
                _actionBtn('Generate Groups', Icons.grid_view, () => _runAction(() => ApiService.generateGroups(widget.tournamentId), 'Groups Generated!')),
                _actionBtn('Generate Schedule', Icons.calendar_today, () => _runAction(() => ApiService.generateSchedule(widget.tournamentId), 'Schedule Ready!')),
                _actionBtn('Generate Knockouts', Icons.account_tree, () => _runAction(() => ApiService.generateKnockouts(widget.tournamentId), 'Knockout Bracket Ready!')),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [Icon(icon, color: Colors.white54, size: 14), const SizedBox(width: 8), Text(text, style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600))]),
  );

  Widget _actionBtn(String label, IconData icon, VoidCallback onPressed) => ElevatedButton.icon(
    onPressed: onPressed,
    icon: Icon(icon, size: 16),
    label: Text(label, style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 12)),
    style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
  );

  // ── TEAMS TAB ────────────────────────────────────────────────────────────────
  Widget _buildTeamsTab() {
    final teams = (_tournament!['teams'] as List?) ?? [];
    final groups = (_tournament!['groups'] as List?) ?? [];

    if (teams.isEmpty) return Center(child: Text('No teams registered yet.', style: GoogleFonts.outfit(color: Colors.grey)));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: teams.length,
      itemBuilder: (context, idx) {
        final t = teams[idx];
        final group = groups.firstWhere((g) => g['id'] == t['groupId'], orElse: () => null);
        final playerCount = (t['players'] as List? ?? []).length;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: _primary,
                radius: 24,
                child: Text(t['name'][0].toUpperCase(), style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(t['name'], style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 15)),
                      if (group != null) ...[
                        const SizedBox(width: 8),
                        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)), child: Text(group['name'], style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.blue.shade700))),
                      ],
                    ]),
                    if (t['captain'] != null && t['captain'].toString().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('Captain: ${t['captain']}', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
                    ],
                    if (t['district'] != null && t['district'].toString().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text('${_titleCase(t['district'])}${t['captainMobile'] != null && t['captainMobile'].toString().isNotEmpty ? ' • ${t['captainMobile']}' : ''}',
                          style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                    ],
                    const SizedBox(height: 6),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: playerCount > 0 ? Colors.green.shade50 : Colors.grey.shade100, borderRadius: BorderRadius.circular(10)), child: Text('$playerCount player${playerCount != 1 ? 's' : ''}', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: playerCount > 0 ? Colors.green.shade700 : Colors.grey))),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── SCHEDULE TAB ─────────────────────────────────────────────────────────────
  Widget _buildScheduleTab() {
    final matches = ((_tournament!['matches'] as List?) ?? []).where((m) => m['tournamentRound'] == 'group').toList();
    matches.sort((a, b) {
      final dA = DateTime.tryParse(a['date'] ?? '') ?? DateTime.now();
      final dB = DateTime.tryParse(b['date'] ?? '') ?? DateTime.now();
      return dA.compareTo(dB);
    });

    if (matches.isEmpty) return Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.calendar_today, size: 48, color: Colors.grey), const SizedBox(height: 16), Text('No schedule yet. Generate schedule from the Info tab.', textAlign: TextAlign.center, style: GoogleFonts.outfit(color: Colors.grey, fontSize: 14))])));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: matches.length,
      itemBuilder: (context, idx) {
        final m = matches[idx];
        final isLive = m['status'] == 'live';
        final isCompleted = m['status'] == 'completed';
        return GestureDetector(
          onTap: isCompleted || isLive ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => ScorecardScreen(matchId: (m['_id'] ?? m['id'] ?? '').toString()))) : null,
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: isLive ? Colors.red.shade200 : Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: isLive ? Colors.red : isCompleted ? Colors.green : _primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Center(child: Text('${m['matchNumber'] ?? idx + 1}', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: isLive ? Colors.white : isCompleted ? Colors.white : _primary))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${m['teamA']} vs ${m['teamB']}', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14)),
                      Text(_fmtDate(m['date']), style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                      if (m['venue'] != null && m['venue'].toString().isNotEmpty) Text(_titleCase(m['venue']), style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey.shade500)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: isLive ? Colors.red : isCompleted ? Colors.green : Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
                  child: Text(m['status']?.toString().toUpperCase() ?? '', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: isLive || isCompleted ? Colors.white : Colors.grey.shade600)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── STANDINGS TAB ────────────────────────────────────────────────────────────
  Widget _buildStandingsTab() {
    if (_pointsTable.isEmpty) return Center(child: Text('No standings yet. Complete group matches to see points.', textAlign: TextAlign.center, style: GoogleFonts.outfit(color: Colors.grey)));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pointsTable.length,
      itemBuilder: (context, idx) {
        final group = _pointsTable[idx];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(group['groupName'], style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18, color: _primary)),
            ),
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
              clipBehavior: Clip.hardEdge,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: MaterialStateProperty.all(Colors.grey.shade50),
                  dataRowMinHeight: 44,
                  columns: [
                    DataColumn(label: Text('TEAM', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 11))),
                    DataColumn(label: Text('M', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 11))),
                    DataColumn(label: Text('W', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 11))),
                    DataColumn(label: Text('L', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 11))),
                    DataColumn(label: Text('PTS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 11, color: _primary))),
                    DataColumn(label: Text('NRR', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 11))),
                  ],
                  rows: (group['teamStats'] as List).map<DataRow>((t) => DataRow(cells: [
                    DataCell(Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(t['teamName'], style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13)),
                      if (t['district'] != null && t['district'].toString().isNotEmpty)
                        Text(t['district'], style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey)),
                    ])),
                    DataCell(Text(t['matches'].toString(), style: GoogleFonts.outfit(fontWeight: FontWeight.w600))),
                    DataCell(Text(t['wins'].toString(), style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.green))),
                    DataCell(Text(t['losses'].toString(), style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.red))),
                    DataCell(Text(t['points'].toString(), style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: _primary, fontSize: 15))),
                    DataCell(Text(t['nrr'].toString(), style: GoogleFonts.outfit(fontWeight: FontWeight.w600))),
                  ])).toList(),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  // ── BRACKET TAB ───────────────────────────────────────────────────────────────
  Widget _buildBracketTab() {
    final matches = ((_tournament!['matches'] as List?) ?? []).where((m) => m['tournamentRound'] != 'group' && m['tournamentRound'] != 'none').toList();
    if (matches.isEmpty) return Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.account_tree, size: 48, color: Colors.grey), const SizedBox(height: 16), Text('Knockout bracket will appear here\nafter group stages complete.', textAlign: TextAlign.center, style: GoogleFonts.outfit(color: Colors.grey, fontSize: 14))])));

    // Group by round
    final Map<String, List<dynamic>> byRound = {};
    for (final m in matches) {
      final r = m['tournamentRound'] ?? 'Other';
      byRound.putIfAbsent(r, () => []).add(m);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: byRound.entries.map((entry) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(color: _primary, borderRadius: BorderRadius.circular(20)),
            child: Text(entry.key.toUpperCase(), style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
          ),
          ...entry.value.map((m) {
            final isLive = m['status'] == 'live';
            final isCompleted = m['status'] == 'completed';
            final winner = m['score']?['winner']?.toString();
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: isLive ? Colors.red.shade200 : Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
              clipBehavior: Clip.hardEdge,
              child: Column(
                children: [
                  Container(height: 4, color: isLive ? Colors.red : isCompleted ? Colors.green : Colors.grey.shade200),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        Row(children: [
                          Expanded(child: Text(m['teamA'] ?? '', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 15, color: winner == m['teamA'] ? Colors.green : null))),
                          if (isCompleted && m['innings'] != null) Text(_getScore(m, m['teamA']), style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14, color: _primary)),
                        ]),
                        const SizedBox(height: 4),
                        Row(children: [
                          Expanded(child: Text('vs', style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey))),
                        ]),
                        const SizedBox(height: 4),
                        Row(children: [
                          Expanded(child: Text(m['teamB'] ?? '', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 15, color: winner == m['teamB'] ? Colors.green : null))),
                          if (isCompleted && m['innings'] != null) Text(_getScore(m, m['teamB']), style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.grey.shade700)),
                        ]),
                        const SizedBox(height: 10),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text(_fmtDate(m['date']), style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: isLive ? Colors.red : isCompleted ? Colors.green : Colors.grey.shade100, borderRadius: BorderRadius.circular(20)), child: Text(m['status']?.toString().toUpperCase() ?? '', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: isLive || isCompleted ? Colors.white : Colors.grey.shade600))),
                        ]),
                        if (winner != null && isCompleted) ...[
                          const SizedBox(height: 8),
                          Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10)), child: Text('🏆 $winner won', textAlign: TextAlign.center, style: GoogleFonts.outfit(color: Colors.green.shade800, fontWeight: FontWeight.w900, fontSize: 12))),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      )).toList(),
    );
  }

  String _getScore(Map<String, dynamic> m, String? team) {
    final innings = m['innings'] as List? ?? [];
    final inn = innings.firstWhere((i) => i['team'] == team, orElse: () => null);
    if (inn == null) return '';
    return '${inn['runs']}/${inn['wickets']} (${inn['overs']}ov)';
  }

  void _showRegisterDialog() {
    final nameCtrl = TextEditingController();
    final captainCtrl = TextEditingController();
    final mobileCtrl = TextEditingController();
    final districtCtrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text('Register Team', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: _primary)),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Team Name *', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: captainCtrl, decoration: const InputDecoration(labelText: 'Captain Name', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: mobileCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Captain Mobile', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: districtCtrl, decoration: const InputDecoration(labelText: 'District', border: OutlineInputBorder())),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: _primary),
          onPressed: () async {
            if (nameCtrl.text.trim().isEmpty) return;
            await _runAction(() => ApiService.registerTeam(widget.tournamentId, nameCtrl.text.trim(), captain: captainCtrl.text.trim(), captainMobile: mobileCtrl.text.trim(), district: districtCtrl.text.trim()), 'Team Registered!');
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: Text('Register', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.white)),
        ),
      ],
    ));
  }
}
