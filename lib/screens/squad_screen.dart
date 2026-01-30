import 'package:flutter/material.dart';
import '../services/api_service.dart';

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

  Future<void> _saveSquads() async {
    List<String> teamA = _controllersA.map((c) => _capitalize(c.text.trim())).where((s) => s.isNotEmpty).toList();
    List<String> teamB = _controllersB.map((c) => _capitalize(c.text.trim())).where((s) => s.isNotEmpty).toList();

    if (teamA.isEmpty || teamB.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('At least one player per team is required!')));
      return;
    }

    try {
      Map<String, dynamic> updateData = {
        'teamASquad': teamA,
        'teamBSquad': teamB
      };
      
      await ApiService.updateMatch((widget.match['_id'] ?? widget.match['id']).toString(), updateData);
      
      // Update local reference so caller sees the change
      widget.match['teamASquad'] = teamA;
      widget.match['teamBSquad'] = teamB;
      
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Squads Saved!')));
      Navigator.pop(context, true); 
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save squads')));
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
          IconButton(icon: Icon(Icons.save), onPressed: _saveSquads)
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTeamList(_controllersA),
          _buildTeamList(_controllersB),
        ],
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
              if (val.isNotEmpty && val[0] != val[0].toUpperCase()) {
                 controllers[index].value = controllers[index].value.copyWith(
                   text: _capitalize(val),
                   selection: TextSelection.collapsed(offset: val.length)
                 );
              }
            },
          ),
        );
      },
    );
  }
}
