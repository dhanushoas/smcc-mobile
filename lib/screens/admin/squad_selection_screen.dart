import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SquadSelectionScreen extends StatefulWidget {
  final String teamA;
  final String teamB;
  final List<String> initialSquadA;
  final List<String> initialSquadB;

  const SquadSelectionScreen({
    Key? key,
    required this.teamA,
    required this.teamB,
    required this.initialSquadA,
    required this.initialSquadB,
  }) : super(key: key);

  @override
  _SquadSelectionScreenState createState() => _SquadSelectionScreenState();
}

class _SquadSelectionScreenState extends State<SquadSelectionScreen> {
  late List<String> _squadA;
  late List<String> _squadB;

  @override
  void initState() {
    super.initState();
    _squadA = List<String>.from(widget.initialSquadA);
    _squadB = List<String>.from(widget.initialSquadB);
    
    // Ensure at least 11 slots for UI
    while(_squadA.length < 11) _squadA.add('');
    while(_squadB.length < 11) _squadB.add('');
  }

  void _save() {
    final sA = _squadA.where((e) => e.trim().isNotEmpty).toList();
    final sB = _squadB.where((e) => e.trim().isNotEmpty).toList();

    if (sA.length < 11 || sB.length < 11) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least 11 players for each team.'))
      );
      return;
    }

    Navigator.pop(context, {
      'squadA': sA,
      'squadB': sB,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('SELECT SQUADS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          height: 60,
          child: ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text('SAVE SQUADS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16)),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTeamSection(widget.teamA, _squadA, isTeamA: true),
            const SizedBox(height: 32),
            _buildTeamSection(widget.teamB, _squadB, isTeamA: false),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamSection(String teamName, List<String> squad, {required bool isTeamA}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${teamName.toUpperCase()} PLAYERS',
          style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.blueAccent, letterSpacing: 1),
        ),
        const SizedBox(height: 12),
        for (int i = 0; i < squad.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextFormField(
              initialValue: squad[i],
              onChanged: (v) => squad[i] = v,
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: 'Player ${i + 1}',
                isDense: true,
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
        TextButton.icon(
          onPressed: () => setState(() => squad.add('')),
          icon: const Icon(Icons.add, size: 20),
          label: const Text('Add More Players'),
        ),
      ],
    );
  }
}
