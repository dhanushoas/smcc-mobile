import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../widgets/app_footer.dart';

class SquadScreen extends StatefulWidget {
  final Map<String, dynamic> match;
  
  SquadScreen({required this.match});

  @override
  _SquadScreenState createState() => _SquadScreenState();
}

class _SquadScreenState extends State<SquadScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<TextEditingController> _controllersA = [];
  List<TextEditingController> _controllersB = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initSquads();
  }

  void _initSquads() {
    List<dynamic> squadA = widget.match['teamASquad'] ?? [];
    List<dynamic> squadB = widget.match['teamBSquad'] ?? [];

    for (int i = 0; i < 11; i++) {
      String valA = i < squadA.length ? squadA[i] : '';
      _controllersA.add(TextEditingController(text: valA));

      String valB = i < squadB.length ? squadB[i] : '';
      _controllersB.add(TextEditingController(text: valB));
    }
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  bool _isSaving = false;

   Future<void> _saveSquads() async {
    if (_isSaving) return;
    
    List<String> teamA = _controllersA.map((c) => _capitalize(c.text.trim())).where((s) => s.isNotEmpty).toList();
    List<String> teamB = _controllersB.map((c) => _capitalize(c.text.trim())).where((s) => s.isNotEmpty).toList();

    if (teamA.length < 11 || teamB.length < 11) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exactly 11 players per team are required!'), backgroundColor: Colors.red));
      return;
    }

    // 1. Check for duplicates within Team A
    if (teamA.toSet().length != teamA.length) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Duplicate names found in ${widget.match['teamA']} squad!'), backgroundColor: Colors.red));
      return;
    }

    // 2. Check for duplicates within Team B
    if (teamB.toSet().length != teamB.length) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Duplicate names found in ${widget.match['teamB']} squad!'), backgroundColor: Colors.red));
      return;
    }

    // 3. Check for names in both teams
    var overlap = teamA.toSet().intersection(teamB.toSet());
    if (overlap.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Players cannot play for both teams: ${overlap.join(", ")}'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isSaving = true);
    try {
      Map<String, dynamic> updateData = {
        'teamASquad': teamA,
        'teamBSquad': teamB
      };
      
      await ApiService.updateMatch((widget.match['_id'] ?? widget.match['id']).toString(), updateData);
      
      // Update local reference so caller sees the change
      widget.match['teamASquad'] = teamA;
      widget.match['teamBSquad'] = teamB;
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Squads Saved Successfully!'), backgroundColor: Colors.green));
        Navigator.pop(context, true); 
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save squads: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Squads'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: widget.match['teamA']),
            Tab(text: widget.match['teamB']),
          ],
        ),
        actions: [
          _isSaving 
            ? Center(child: Padding(padding: EdgeInsets.only(right: 15), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))))
            : IconButton(icon: Icon(Icons.save), onPressed: _saveSquads)
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTeamList(_controllersA),
          _buildTeamList(_controllersB),
        ],
      ),
      bottomNavigationBar: Container(
        height: 100,
        child: AppFooter(),
      ),
    );
  }

  Widget _buildTeamList(List<TextEditingController> controllers) {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: 11,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: TextField(
            controller: controllers[index],
            decoration: InputDecoration(
              labelText: 'Player ${index + 1}',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
            onChanged: (val) {
              if (val.isNotEmpty) {
                 String cleaned = val.replaceAll(RegExp(r'[^a-zA-Z\s]'), '');
                 if (cleaned != val) {
                    controllers[index].value = controllers[index].value.copyWith(
                      text: cleaned,
                      selection: TextSelection.collapsed(offset: cleaned.length)
                    );
                    val = cleaned;
                 }
                 if (val.isNotEmpty && val[0] != val[0].toUpperCase()) {
                    controllers[index].value = controllers[index].value.copyWith(
                      text: _capitalize(val),
                      selection: TextSelection.collapsed(offset: val.length)
                    );
                 }
              }
            },
          ),
        );
      },
    );
  }
}
