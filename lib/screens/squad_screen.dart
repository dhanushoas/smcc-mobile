import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
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
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initSquads();
  }

  void _initSquads() {
    List squadA = widget.match['teamASquad'] ?? [], squadB = widget.match['teamBSquad'] ?? [];
    for (int i = 0; i < 11; i++) {
      _controllersA.add(TextEditingController(text: i < squadA.length ? squadA[i] : ''));
      _controllersB.add(TextEditingController(text: i < squadB.length ? squadB[i] : ''));
    }
  }

  String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  void _showSnackBar(String m, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(m, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      backgroundColor: isError ? Colors.red : Colors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Future<void> _saveSquads() async {
    if (_isSaving) return;
    List<String> a = _controllersA.map((c) => _capitalize(c.text.trim())).where((s) => s.isNotEmpty).toList();
    List<String> b = _controllersB.map((c) => _capitalize(c.text.trim())).where((s) => s.isNotEmpty).toList();

    if (a.length < 11 || b.length < 11) { _showSnackBar('11 players per team required', isError: true); return; }
    if (a.toSet().length != a.length || b.toSet().length != b.length) { _showSnackBar('Duplicate names found', isError: true); return; }
    if (a.toSet().intersection(b.toSet()).isNotEmpty) { _showSnackBar('Player in both teams found', isError: true); return; }

    setState(() => _isSaving = true);
    try {
      await ApiService.updateMatch((widget.match['_id'] ?? widget.match['id']).toString(), {'teamASquad': a, 'teamBSquad': b});
      widget.match['teamASquad'] = a; widget.match['teamBSquad'] = b;
      if (mounted) { _showSnackBar('Squads Saved!'); Navigator.pop(context, true); }
    } catch (e) { if (mounted) { setState(() => _isSaving = false); _showSnackBar('Failed: $e', isError: true); } }
  }

  @override
  Widget build(BuildContext context) {
    final primaryBlue = Color(0xFF2563EB);
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: primaryBlue, size: 20), onPressed: () => Navigator.pop(context)),
        title: Text('SQUAD MANAGEMENT', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: primaryBlue, fontSize: 16, letterSpacing: 1.2)),
        actions: [
          _isSaving 
            ? Center(child: Padding(padding: EdgeInsets.only(right: 15), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: primaryBlue))))
            : IconButton(icon: Icon(Icons.check_circle_rounded, color: primaryBlue), onPressed: _saveSquads),
          SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: primaryBlue,
          indicatorWeight: 4,
          labelColor: primaryBlue,
          unselectedLabelColor: Colors.grey,
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13),
          tabs: [Tab(text: widget.match['teamA'].toUpperCase()), Tab(text: widget.match['teamB'].toUpperCase())],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildTeamList(_controllersA, primaryBlue), _buildTeamList(_controllersB, primaryBlue)],
      ),
    );
  }

  Widget _buildTeamList(List<TextEditingController> controllers, Color primaryBlue) {
    return ListView.builder(
      padding: EdgeInsets.all(24),
      itemCount: 11,
      itemBuilder: (context, i) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: TextField(
            controller: controllers[i],
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              labelText: 'PLAYER ${i + 1}',
              labelStyle: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.5),
              prefixIcon: Icon(Icons.person_outline_rounded, size: 18, color: primaryBlue),
              filled: true,
              fillColor: primaryBlue.withOpacity(0.03),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
            onChanged: (v) {
              if (v.isNotEmpty) {
                 String c = v.replaceAll(RegExp(r'[^a-zA-Z\s]'), '');
                 if (c != v) { controllers[i].value = controllers[i].value.copyWith(text: c, selection: TextSelection.collapsed(offset: c.length)); v = c; }
                 if (v.isNotEmpty && v[0] != v[0].toUpperCase()) controllers[i].value = controllers[i].value.copyWith(text: _capitalize(v), selection: TextSelection.collapsed(offset: v.length));
              }
            },
          ),
        );
      },
    );
  }
}
