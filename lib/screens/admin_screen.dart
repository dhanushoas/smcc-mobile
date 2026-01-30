import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'admin_live_match.dart';

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
    fetchMatches();
  }

  Future<void> fetchMatches() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      final data = await ApiService.getMatches();
      if (mounted) {
        setState(() {
          matches = data;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load matches: $e'))
        );
      }
    }
  }

  void _showUpdateDialog(var match) {
    final titleController = TextEditingController(text: match['title'] ?? '');
    final seriesController = TextEditingController(text: match['series'] ?? 'SMCC Premier League');
    final venueController = TextEditingController(text: match['venue'] ?? '');
    final oversController = TextEditingController(text: match['totalOvers']?.toString() ?? '20');
    final momController = TextEditingController(text: match['manOfTheMatch'] ?? '');
    DateTime selectedDate = DateTime.tryParse(match['date'] ?? '') ?? DateTime.now();
    TimeOfDay selectedTime = TimeOfDay(hour: selectedDate.hour, minute: selectedDate.minute);
    String status = match['status'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Edit Match Info'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleController, decoration: InputDecoration(labelText: 'Match Title', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                SizedBox(height: 12),
                TextField(controller: seriesController, decoration: InputDecoration(labelText: 'Series Name', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                SizedBox(height: 12),
                TextField(controller: venueController, decoration: InputDecoration(labelText: 'Venue', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                SizedBox(height: 12),
                TextField(controller: oversController, decoration: InputDecoration(labelText: 'Total Overs Limit', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), keyboardType: TextInputType.number),
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(12)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: status,
                      items: ['upcoming', 'live', 'completed'].map((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))).toList(),
                      onChanged: (val) => setDialogState(() => status = val!),
                    ),
                  ),
                ),
                SizedBox(height: 12),
                if (status == 'completed') ...[
                  TextField(controller: momController, decoration: InputDecoration(labelText: 'Man of the Match', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                  SizedBox(height: 12),
                ],
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.calendar_today, color: Color(0xFF1E3C72)),
                  title: Text('Date: ${selectedDate.toString().split(' ')[0]}'),
                  onTap: () async {
                    final picked = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
                    if (picked != null) setDialogState(() => selectedDate = picked);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.access_time, color: Color(0xFF1E3C72)),
                  title: Text('Time: ${selectedTime.format(context)}'),
                  onTap: () async {
                    final picked = await showTimePicker(context: context, initialTime: selectedTime);
                    if (picked != null) setDialogState(() => selectedTime = picked);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF1E3C72), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () async {
                String isoDate = "${selectedDate.toIso8601String().split('T')[0]}T${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}:00";
                
                try {
                  await ApiService.updateMatch(match['_id'], {
                    'title': titleController.text,
                    'series': seriesController.text,
                    'venue': venueController.text,
                    'totalOvers': int.tryParse(oversController.text) ?? 20,
                    'status': status,
                    'manOfTheMatch': momController.text,
                    'date': isoDate,
                  });
                  Navigator.pop(context);
                  fetchMatches();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Updated successfully')));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                }
              },
              child: Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateDialog() {
    final titleController = TextEditingController();
    final seriesController = TextEditingController(text: 'SMCC Premier League');
    final teamAController = TextEditingController();
    final teamBController = TextEditingController();
    final venueController = TextEditingController();
    final oversController = TextEditingController(text: '20');
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay(hour: 9, minute: 0);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('New Match', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleController, decoration: InputDecoration(labelText: 'Match Title', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                SizedBox(height: 12),
                TextField(controller: seriesController, decoration: InputDecoration(labelText: 'Series Name', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: TextField(controller: teamAController, decoration: InputDecoration(labelText: 'Team A', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))),
                    SizedBox(width: 10),
                    Text('VS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    SizedBox(width: 10),
                    Expanded(child: TextField(controller: teamBController, decoration: InputDecoration(labelText: 'Team B', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))),
                  ],
                ),
                SizedBox(height: 12),
                TextField(controller: venueController, decoration: InputDecoration(labelText: 'Venue', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                SizedBox(height: 12),
                TextField(controller: oversController, decoration: InputDecoration(labelText: 'Total Overs', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), keyboardType: TextInputType.number),
                SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.calendar_today, color: Color(0xFF1E3C72)),
                  title: Text('Date: ${selectedDate.toString().split('00:00')[0]}'),
                  onTap: () async {
                    final picked = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime.now(), lastDate: DateTime(2030));
                    if (picked != null) setDialogState(() => selectedDate = picked);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.access_time, color: Color(0xFF1E3C72)),
                  title: Text('Time: ${selectedTime.format(context)}'),
                  onTap: () async {
                    final picked = await showTimePicker(context: context, initialTime: selectedTime);
                    if (picked != null) setDialogState(() => selectedTime = picked);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF1E3C72), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () async {
                if (teamAController.text.isEmpty || teamBController.text.isEmpty) return;
                
                String isoDate = "${selectedDate.toIso8601String().split('T')[0]}T${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}:00";

                try {
                  await ApiService.createMatch({
                    'title': titleController.text.isEmpty ? "${teamAController.text} vs ${teamBController.text}" : titleController.text,
                    'series': seriesController.text,
                    'teamA': teamAController.text,
                    'teamB': teamBController.text,
                    'venue': venueController.text,
                    'totalOvers': int.tryParse(oversController.text) ?? 20,
                    'date': isoDate,
                    'status': 'upcoming'
                  });
                  Navigator.pop(context);
                  fetchMatches();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Match Created! Ensure you add squads before starting.')));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteMatch(String id) async {
     bool? confirm = await showDialog<bool>(
       context: context,
       builder: (context) => AlertDialog(
         title: Text('Delete Match?'),
         content: Text('This action cannot be undone.'),
         actions: [
           TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel')),
           TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Delete', style: TextStyle(color: Colors.red))),
         ],
       )
     );

     if (confirm == true) {
       try {
         await ApiService.deleteMatch(id);
         fetchMatches();
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Match Deleted')));
       } catch (e) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete')));
       }
      }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('Admin Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Color(0xFF1E3C72),
        elevation: 0,
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: fetchMatches)
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Color(0xFF1E3C72),
        onPressed: _showCreateDialog,
        icon: Icon(Icons.add, color: Colors.white),
        label: Text('NEW MATCH', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          int crossAxisCount = constraints.maxWidth > 800 ? 3 : (constraints.maxWidth > 500 ? 2 : 1);
          
          if (isLoading) {
            return Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                 CircularProgressIndicator(color: Color(0xFF1E3C72)),
                 SizedBox(height: 10),
                 Text('Loading Matches...', style: TextStyle(color: Colors.grey)),
              ],
            ));
          }

          if (matches.isEmpty) {
            return Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_note, size: 80, color: Colors.grey.shade300),
                SizedBox(height: 16),
                Text('No matches found', style: TextStyle(color: Colors.grey, fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                ElevatedButton(onPressed: fetchMatches, child: Text('Refresh'))
              ],
            ));
          }

          return Padding(
              padding: const EdgeInsets.all(16.0),
              child: GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 2.2,
                  ),
                  itemCount: matches.length,
                  itemBuilder: (context, index) {
                    final match = matches[index];
                    return _buildAdminCard(match);
                  },
              ),
          );
        },
      ),
    );
  }

  Widget _buildAdminCard(dynamic match) {
    bool isLive = match['status'] == 'live';
    
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminLiveMatchScreen(matchData: match))),
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(match['title'] ?? 'Match', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey.shade800), overflow: TextOverflow.ellipsis),
                    SizedBox(height: 4),
                    Text('${match['teamA']} vs ${match['teamB']}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF1E3C72))),
                    SizedBox(height: 8),
                    Container(
                       padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                       decoration: BoxDecoration(color: isLive ? Colors.red : Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                       child: Text(match['status'].toString().toUpperCase(), style: TextStyle(color: isLive ? Colors.white : Colors.black87, fontSize: 8, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   IconButton(icon: Icon(Icons.edit_outlined, color: Colors.blue), onPressed: () => _showUpdateDialog(match)),
                   IconButton(icon: Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _deleteMatch(match['_id'])),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
