import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'profile_screen.dart';
import '../services/api_service.dart';
import 'admin_live_match.dart';
import '../widgets/app_footer.dart';

class AdminScreen extends StatefulWidget {
  @override
  _AdminScreenState createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  List<dynamic> matches = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString('token') == null) {
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ProfileScreen()));
      }
    } else {
      fetchMatches();
    }
  }

  Future<void> fetchMatches() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      final data = await ApiService.getMatches();
      if (mounted) setState(() { matches = data; isLoading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        _showSnackBar('Failed to load: ${e.toString().replaceAll('Exception: ', '')}', isError: true);
      }
    }
  }

  void _showSnackBar(String m, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(m, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      backgroundColor: isError ? Colors.red : Colors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final primaryBlue = Color(0xFF2563EB);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.home_rounded, color: primaryBlue, size: 24), onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst)),
        title: Text('ADMIN DASHBOARD', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: primaryBlue, fontSize: 16, letterSpacing: 1.2)),
        actions: [IconButton(icon: Icon(Icons.refresh_rounded, color: primaryBlue), onPressed: fetchMatches)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primaryBlue,
        onPressed: _showCreateDialog,
        icon: Icon(Icons.add_rounded, color: Colors.white),
        label: Text('NEW MATCH', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 13)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
      ),
      body: isLoading ? Center(child: CircularProgressIndicator(color: primaryBlue)) : (matches.isEmpty ? _buildEmptyState() : _buildMatchGrid(primaryBlue)),
    );
  }

  Widget _buildEmptyState() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.event_note_rounded, size: 80, color: Colors.grey.withOpacity(0.2)),
    SizedBox(height: 24),
    Text('NO MATCHES FOUND', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.grey)),
    SizedBox(height: 12),
    TextButton(onPressed: fetchMatches, child: Text('REFRESH LIST', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Color(0xFF2563EB))))
  ]));

  Widget _buildMatchGrid(Color primaryBlue) {
    return Column(children: [
      Expanded(
        child: GridView.builder(
          padding: EdgeInsets.all(24),
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 500, mainAxisExtent: 140, crossAxisSpacing: 20, mainAxisSpacing: 20),
          itemCount: matches.length,
          itemBuilder: (context, i) => _buildAdminCard(matches[i], primaryBlue),
        ),
      ),
      AppFooter(),
    ]);
  }

  Widget _buildAdminCard(dynamic m, Color primary) {
    bool isLive = m['status'] == 'live';
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: primary.withOpacity(0.1)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: Offset(0, 5))],
      ),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminLiveMatchScreen(matchData: m))),
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(m['title']?.toUpperCase() ?? 'MATCH', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 10, color: Colors.grey, letterSpacing: 1), overflow: TextOverflow.ellipsis),
                  SizedBox(height: 6),
                  Text('${m['teamA']} VS ${m['teamB']}'.toUpperCase(), style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: primary)),
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: isLive ? Colors.red : primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text(m['status'].toString().toUpperCase(), style: GoogleFonts.outfit(color: isLive ? Colors.white : primary, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  ),
                ]),
              ),
              Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                 if (m['status'] != 'completed') IconButton(icon: Icon(Icons.edit_note_rounded, color: Colors.blueGrey, size: 28), onPressed: () => _showUpdateDialog(m)),
                 IconButton(icon: Icon(Icons.delete_sweep_rounded, color: Colors.red.withOpacity(0.8), size: 24), onPressed: () => _deleteMatch(m['_id'].toString())),
              ])
            ],
          ),
        ),
      ),
    );
  }

  void _showUpdateDialog(var m) {
    final tC = TextEditingController(text: m['title'] ?? ''), sC = TextEditingController(text: m['series'] ?? ''), vC = TextEditingController(text: m['venue'] ?? ''), oC = TextEditingController(text: m['totalOvers']?.toString() ?? '20');
    DateTime sd = (DateTime.tryParse(m['date'] ?? '') ?? DateTime.now()).toLocal(); TimeOfDay st = TimeOfDay(hour: sd.hour, minute: sd.minute); String status = m['status'];
    String? localError;
    showDialog(context: context, builder: (context) => StatefulBuilder(builder: (context, set) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text('EDIT MATCH INFO', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16)),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (localError != null) ...[
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Text(localError!, style: GoogleFonts.outfit(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          SizedBox(height: 16),
        ],
        _df(tC, 'MATCH TITLE'), _df(sC, 'SERIES NAME'), _df(vC, 'VENUE'), _df(oC, 'OVERS LIMIT', isNum: true),
        SizedBox(height: 12),
        _dropDown(status, (v) => set(() => status = v!)),
        if (status == 'completed') ...[SizedBox(height: 12)],
        _dtTile('DATE', sd.toString().split(' ')[0], () async { final p = await showDatePicker(context: context, initialDate: sd, firstDate: DateTime(2020), lastDate: DateTime(2030)); if (p != null) set(() => sd = p); }),
        _dtTile('TIME', st.format(context), () async { final p = await showTimePicker(context: context, initialTime: st); if (p != null) set(() => st = p); }),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('CANCEL', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.grey))),
        ElevatedButton(onPressed: () async {
          String iso = "${sd.toIso8601String().split('T')[0]}T${st.hour.toString().padLeft(2, '0')}:${st.minute.toString().padLeft(2, '0')}:00";
          try { 
            await ApiService.updateMatch(m['_id'].toString(), {'title': tC.text, 'series': sC.text, 'venue': vC.text, 'totalOvers': int.tryParse(oC.text) ?? 20, 'status': status, 'date': iso}); 
            Navigator.pop(context); fetchMatches(); _showSnackBar('Updated Successfully!'); 
          }
          catch (e) { set(() => localError = e.toString().replaceAll('Exception: ', '')); }
        }, style: _btnStyle(Color(0xFF2563EB)), child: Text('SAVE CHANGES'))
      ],
    )));
  }

  void _showCreateDialog() {
    final tC = TextEditingController(), sC = TextEditingController(text: 'SMCC Premier League'), taC = TextEditingController(), tbC = TextEditingController(), vC = TextEditingController(), oC = TextEditingController(text: '20');
    DateTime sd = DateTime.now(); TimeOfDay st = TimeOfDay(hour: 9, minute: 0);
    String? localError;
    List<String>? squadA, squadB;

    showDialog(context: context, builder: (context) => StatefulBuilder(builder: (context, set) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('CREATE NEW MATCH', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16)),
          if (matches.isNotEmpty) 
            TextButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text('SELECT MATCH TO COPY', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14)),
                    content: Container(
                      width: double.maxFinite,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: matches.length,
                        itemBuilder: (ctx, i) => ListTile(
                          title: Text('${matches[i]['teamA']} vs ${matches[i]['teamB']}', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
                          subtitle: Text(matches[i]['series'] ?? '', style: GoogleFonts.outfit(fontSize: 10)),
                          onTap: () {
                            set(() {
                              tC.text = matches[i]['title'] ?? '';
                              sC.text = matches[i]['series'] ?? '';
                              taC.text = matches[i]['teamA'] ?? '';
                              tbC.text = matches[i]['teamB'] ?? '';
                              vC.text = matches[i]['venue'] ?? '';
                              oC.text = matches[i]['totalOvers']?.toString() ?? '20';
                              squadA = matches[i]['teamASquad'] != null ? List<String>.from(matches[i]['teamASquad']) : null;
                              squadB = matches[i]['teamBSquad'] != null ? List<String>.from(matches[i]['teamBSquad']) : null;
                            });
                            Navigator.pop(ctx);
                          },
                        ),
                      ),
                    ),
                  )
                );
              },
              icon: Icon(Icons.copy_all_rounded, size: 16),
              label: Text('COPY', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 10)),
              style: TextButton.styleFrom(foregroundColor: Color(0xFF2563EB)),
            ),
        ],
      ),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (localError != null) ...[
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Text(localError!, style: GoogleFonts.outfit(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          SizedBox(height: 16),
        ],
        _df(tC, 'MATCH TITLE (OPTIONAL)'), _df(sC, 'SERIES NAME'),
        Row(children: [Expanded(child: _df(taC, 'TEAM A')), SizedBox(width: 8), Text('VS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 10, color: Colors.grey)), SizedBox(width: 8), Expanded(child: _df(tbC, 'TEAM B'))]),
        _df(vC, 'VENUE'), _df(oC, 'TOTAL OVERS', isNum: true),
        if (squadA != null && squadB != null) 
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  Icon(Icons.people_alt_rounded, color: Colors.green, size: 16),
                  SizedBox(width: 8),
                  Text('Squads will be copied from previous match', style: GoogleFonts.outfit(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        _dtTile('DATE', sd.toString().split(' ')[0], () async { final p = await showDatePicker(context: context, initialDate: sd, firstDate: DateTime.now(), lastDate: DateTime(2030)); if (p != null) set(() => sd = p); }),
        _dtTile('TIME', st.format(context), () async { final p = await showTimePicker(context: context, initialTime: st); if (p != null) set(() => st = p); }),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('CANCEL', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.grey))),
        ElevatedButton(onPressed: () async {
          if (taC.text.isEmpty || tbC.text.isEmpty) { set(() => localError = 'Teams are required!'); return; }
          String iso = "${sd.toIso8601String().split('T')[0]}T${st.hour.toString().padLeft(2, '0')}:${st.minute.toString().padLeft(2, '0')}:00";
          try { 
            Map<String, dynamic> payload = {
              'title': tC.text.isEmpty ? "${taC.text} vs ${tbC.text}" : tC.text, 
              'series': sC.text, 
              'teamA': taC.text, 
              'teamB': tbC.text, 
              'venue': vC.text, 
              'totalOvers': int.tryParse(oC.text) ?? 20, 
              'date': iso, 
              'status': 'upcoming'
            };
            if (squadA != null) payload['teamASquad'] = squadA;
            if (squadB != null) payload['teamBSquad'] = squadB;

            await ApiService.createMatch(payload); 
            Navigator.pop(context); fetchMatches(); _showSnackBar('Match Created!'); 
          }
          catch (e) { set(() => localError = e.toString().replaceAll('Exception: ', '')); }
        }, style: _btnStyle(Color(0xFF2563EB)), child: Text('CREATE MATCH'))
      ],
    )));
  }

  void _deleteMatch(String id) async {
    bool? confirm = await showDialog(context: context, builder: (context) => AlertDialog(
      title: Text('DELETE MATCH?', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
      content: Text('This action is irreversible.', style: GoogleFonts.outfit()),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text('CANCEL', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.grey))),
        ElevatedButton(onPressed: () => Navigator.pop(context, true), style: _btnStyle(Colors.red), child: Text('DELETE'))
      ],
    ));
    if (confirm == true) { try { await ApiService.deleteMatch(id); fetchMatches(); _showSnackBar('Match Deleted'); } catch (e) { _showSnackBar(e.toString(), isError: true); } }
  }

  Widget _df(TextEditingController c, String l, {bool isNum = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 12.0),
    child: TextField(controller: c, keyboardType: isNum ? TextInputType.number : null, decoration: InputDecoration(labelText: l, labelStyle: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
  );
  Widget _dtTile(String l, String v, VoidCallback t) => ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.event_available_rounded, size: 20, color: Color(0xFF2563EB)), title: Text('$l: $v', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13)), onTap: t);
  ButtonStyle _btnStyle(Color c) => ElevatedButton.styleFrom(backgroundColor: c, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)), textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 12));
  Widget _dropDown(String v, ValueChanged<String?> c) => Container(padding: EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(12)), child: DropdownButtonHideUnderline(child: DropdownButton<String>(isExpanded: true, value: v, items: ['upcoming', 'live', 'completed'].map((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase(), style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 11)))).toList(), onChanged: c)));
}
