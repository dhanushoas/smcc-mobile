import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import 'admin_scoring_screen.dart';
import 'match_form_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  @override
  _AdminDashboardScreenState createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  List<dynamic> _matches = [];
  List<dynamic> _filteredMatches = [];
  bool _loading = true;
  String _searchQuery = '';
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _fetchMatches();
  }

  Future<void> _fetchMatches() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.getMatches();
      setState(() {
        _matches = data;
        _applyFilters();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredMatches = _matches.where((m) {
        final matchesSearch = m['teamA'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
                             m['teamB'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
                             m['series'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
        final matchesStatus = _statusFilter == 'all' || m['status'] == _statusFilter;
        return matchesSearch && matchesStatus;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('ADMIN CONSOLE', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchMatches),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MatchFormScreen())),
        backgroundColor: const Color(0xFF2563EB),
        icon: const Icon(Icons.add_circle_outline, color: Colors.white),
        label: Text('CREATE MATCH', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.white)),
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _fetchMatches,
                    child: _filteredMatches.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredMatches.length,
                            itemBuilder: (context, index) => _buildMatchCard(_filteredMatches[index]),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            onChanged: (val) {
              _searchQuery = val;
              _applyFilters();
            },
            decoration: InputDecoration(
              hintText: 'Search teams or series...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: const Color(0xFFF1F5F9),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('All', 'all'),
                const SizedBox(width: 8),
                _filterChip('Upcoming', 'upcoming'),
                const SizedBox(width: 8),
                _filterChip('Live', 'live'),
                const SizedBox(width: 8),
                _filterChip('Completed', 'completed'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final active = _statusFilter == value;
    return ChoiceChip(
      label: Text(label.toUpperCase(), style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: active ? Colors.white : Colors.blueGrey)),
      selected: active,
      selectedColor: const Color(0xFF2563EB),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _statusFilter = value;
            _applyFilters();
          });
        }
      },
    );
  }

  Widget _buildMatchCard(Map<String, dynamic> match) {
    final status = match['status'] ?? 'upcoming';
    final Color statusColor = status == 'live' ? Colors.red : (status == 'completed' ? Colors.green : Colors.blue);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminScoringScreen(initialMatch: match))),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    (match['series'] ?? 'SMCC LIVE').toString().toUpperCase(),
                    style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.blueAccent),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                    child: Text(status.toUpperCase(), style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: statusColor)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: _teamName(match['teamA'])),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('VS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.grey)),
                  ),
                  Expanded(child: _teamName(match['teamB'], isReverse: true)),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(match['date'] ?? '', style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey)),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.blue),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MatchFormScreen(existingMatch: match))),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                        onPressed: () => _confirmDelete(match),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _teamName(String? name, {bool isReverse = false}) {
    return Text(
      (name ?? 'TBA').toUpperCase(),
      textAlign: isReverse ? TextAlign.right : TextAlign.left,
      style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, color: const Color(0xFF1E293B)),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sports_cricket_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('No matches found', style: GoogleFonts.outfit(color: Colors.grey, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(Map<String, dynamic> match) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Match?'),
        content: Text('Are you sure you want to delete ${match['teamA']} vs ${match['teamB']}? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('DELETE', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ApiService.deleteMatch(match['_id'] ?? match['id']);
        _fetchMatches();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Match deleted')));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }
}
