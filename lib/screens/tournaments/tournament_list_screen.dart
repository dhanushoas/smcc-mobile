import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'tournament_detail_screen.dart';
import '../admin/admin_login_screen.dart';
import '../../services/auth_service.dart';

class TournamentListScreen extends StatefulWidget {
  const TournamentListScreen({super.key});

  @override
  State<TournamentListScreen> createState() => _TournamentListScreenState();
}

class _TournamentListScreenState extends State<TournamentListScreen> {
  List<dynamic> _tournaments = [];
  bool _isLoading = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdmin();
    _loadTournaments();
  }

  Future<void> _checkAdmin() async {
    final isAdmin = await AuthService.isAdmin();
    setState(() => _isAdmin = isAdmin);
  }

  Future<void> _loadTournaments() async {
    try {
      final res = await ApiService.getTournaments();
      setState(() {
        _tournaments = res;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
      setState(() => _isLoading = false);
    }
  }

  void _showCreateDialog() {
    final nameController = TextEditingController();
    int totalTeams = 8;
    String type = 'league_knockout';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('New Tournament', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Tournament Name'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                value: totalTeams,
                decoration: const InputDecoration(labelText: 'Total Teams'),
                items: [8, 12, 16, 20, 24, 32].map((n) => DropdownMenuItem(value: n, child: Text('$n Teams'))).toList(),
                onChanged: (v) => setDialogState(() => totalTeams = v!),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: type,
                decoration: const InputDecoration(labelText: 'Format'),
                items: const [
                  DropdownMenuItem(value: 'league_knockout', child: Text('League + Knockout')),
                  DropdownMenuItem(value: 'knockout', child: Text('Pure Knockout')),
                  DropdownMenuItem(value: 'league', child: Text('Pure League')),
                ],
                onChanged: (v) => setDialogState(() => type = v!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty) return;
                try {
                  await ApiService.createTournament({
                    'name': nameController.text,
                    'totalTeams': totalTeams,
                    'type': type
                  });
                  Navigator.pop(context);
                  _loadTournaments();
                } catch (e) {
                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TOURNAMENTS', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
        backgroundColor: const Color(0xFF032333),
        foregroundColor: Colors.white,
      ),
      floatingActionButton: _isAdmin ? FloatingActionButton(
        onPressed: _showCreateDialog,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ) : null,
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _tournaments.isEmpty 
          ? const Center(child: Text('No tournaments found'))
           : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _tournaments.length,
              itemBuilder: (context, index) {
                final t = _tournaments[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 2,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(15),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => TournamentDetailScreen(tournamentId: t['id'])),
                    ).then((_) => _loadTournaments()),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(children: [
                                _buildBadge(t['type'].toString().replaceAll('_', ' ').toUpperCase(), Colors.blue),
                                if (t['ballType'] != null) ...[
                                  const SizedBox(width: 6),
                                  _buildBadge(t['ballType'].toString().toUpperCase(), Colors.orange),
                                ],
                              ]),
                              _buildBadge(t['status'].toString().toUpperCase(), _getStatusColor(t['status'])),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(t['name'], style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                          if (t['organizer'] != null && t['organizer'].toString().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(children: [const Icon(Icons.business, size: 12, color: Colors.grey), const SizedBox(width: 4), Text(t['organizer'], style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600))]),
                          ],
                          if (t['venue'] != null && t['venue'].toString().isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Row(children: [const Icon(Icons.location_on, size: 12, color: Colors.grey), const SizedBox(width: 4), Text(t['venue'], style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600))]),
                          ],
                          const SizedBox(height: 8),
                          Row(children: [
                            const Icon(Icons.people, size: 13, color: Colors.blueGrey),
                            const SizedBox(width: 4),
                            Text('${t['totalTeams']} teams', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                            if (t['settings']?['oversPerMatch'] != null) ...[
                              const SizedBox(width: 16),
                              const Icon(Icons.sports_cricket, size: 13, color: Colors.blueGrey),
                              const SizedBox(width: 4),
                              Text('${t['settings']['oversPerMatch']} overs', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                            ],
                          ]),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withOpacity(0.5))),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'ongoing': return Colors.red;
      case 'completed': return Colors.green;
      default: return Colors.grey;
    }
  }
}
