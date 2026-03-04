import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';

class MatchFormScreen extends StatefulWidget {
  final Map<String, dynamic>? existingMatch;
  final bool isCopy;
  const MatchFormScreen({Key? key, this.existingMatch, this.isCopy = false}) : super(key: key);

  @override
  _MatchFormScreenState createState() => _MatchFormScreenState();
}

class _MatchFormScreenState extends State<MatchFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _teamAController;
  late TextEditingController _teamBController;
  late TextEditingController _venueController;
  late TextEditingController _oversController;
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  bool _isSaving = false; // Form submission state

  String _competitionType = 'head-to-head'; // Selected competition format
  String _seriesType = 'best_of_3'; // Selected series length

  @override
  void initState() {
    super.initState();
    final m = widget.existingMatch;
    _titleController = TextEditingController(text: m?['title'] ?? '');
    _teamAController = TextEditingController(text: m?['teamA'] ?? '');
    _teamBController = TextEditingController(text: m?['teamB'] ?? '');
    _venueController = TextEditingController(text: m?['venue'] ?? '');
    _oversController = TextEditingController(text: (m?['overs_per_match'] ?? m?['totalOvers'] ?? 20).toString());
    _competitionType = m?['competitionType'] ?? 'head-to-head';
    _seriesType = m?['seriesType'] ?? 'best_of_3';
    
    if (widget.isCopy) {
      _selectedDate = DateTime.now();
      _selectedTime = TimeOfDay.now();
    } else {
      final parsedDate = DateTime.tryParse(m?['date'] ?? '') ?? DateTime.now();
      _selectedDate = parsedDate;
      _selectedTime = (m?['date'] != null) ? TimeOfDay.fromDateTime(parsedDate) : TimeOfDay.now();
    }
  }

  Future<void> _save() async {
    // Validate form inputs (date, time, teams, overs)
    if (!_formKey.currentState!.validate()) return;

    if (_teamAController.text.trim().toLowerCase() == _teamBController.text.trim().toLowerCase()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Both teams cannot be the same')));
      return;
    }

    setState(() => _isSaving = true);
    final fullDate = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final payload = {
      'title': _competitionType == 'head-to-head' 
          ? '${_teamAController.text} vs ${_teamBController.text}' 
          : _titleController.text,
      'teamA': _teamAController.text,
      'teamB': _teamBController.text,
      'venue': _venueController.text,
      'overs_per_match': int.tryParse(_oversController.text) ?? 20,
      'competitionType': _competitionType,
      'seriesType': _seriesType,
      'date': fullDate.toIso8601String(),
      if (widget.existingMatch == null || widget.isCopy) 'status': 'upcoming',
      if (widget.existingMatch == null || widget.isCopy) 'score': {
        'runs': 0, 'wickets': 0, 'overs': '0.0', 'battingTeam': _teamAController.text, 'thisOver': []
      }
    };

    try {
      if (_competitionType == 'series') {
        if (!widget.isCopy && widget.existingMatch != null) {
           // Updating a series match might be restricted, but for parity:
           await ApiService.updateMatch(widget.existingMatch!['id'] ?? widget.existingMatch!['_id'], payload);
        } else {
           await ApiService.createSeries(payload);
        }
      } else if (_competitionType == 'tournament') {
        await ApiService.createTournament(payload);
      } else {
        if (widget.existingMatch != null && !widget.isCopy) {
          await ApiService.updateMatch(widget.existingMatch!['_id'] ?? widget.existingMatch!['id'], payload);
        } else {
          await ApiService.createMatch(payload);
        }
      }
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Match saved successfully')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingMatch != null && !widget.isCopy;
    final isCopy = widget.isCopy;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(isEdit ? 'EDIT MATCH' : (isCopy ? 'NEW MATCH (COPY)' : 'NEW MATCH'), style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          height: 60,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _isSaving 
              ? const CircularProgressIndicator(color: Colors.white)
              : Text('CONFIRM', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16)),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _buildSectionHeader('Competition Type'),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildTypeBtn('head-to-head', 'Match'),
                const SizedBox(width: 8),
                _buildTypeBtn('series', 'Series'),
                const SizedBox(width: 8),
                _buildTypeBtn('tournament', 'T-ment'),
              ],
            ),
            const SizedBox(height: 24),
            if (_competitionType == 'series') ...[
               _buildSectionHeader('Series Type'),
               const SizedBox(height: 12),
               DropdownButtonFormField<String>(
                 value: _seriesType,
                 decoration: InputDecoration(
                   filled: true,
                   fillColor: const Color(0xFFF1F5F9),
                   border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                 ),
                 items: const [
                   DropdownMenuItem(value: 'best_of_3', child: Text('Best of 3')),
                   DropdownMenuItem(value: 'best_of_5', child: Text('Best of 5')),
                   DropdownMenuItem(value: 'best_of_7', child: Text('Best of 7')),
                 ],
                 onChanged: (val) => setState(() => _seriesType = val!),
               ),
               const SizedBox(height: 24),
            ],
            _buildField(
              _competitionType == 'head-to-head' ? 'Match Title' : (_competitionType == 'series' ? 'Series Name' : 'Tournament Name'), 
              _titleController, 
              Icons.emoji_events_outlined,
              enabled: _competitionType != 'head-to-head'
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _buildField('Team A', _teamAController, Icons.shield_outlined)),
                const SizedBox(width: 16),
                Expanded(child: _buildField('Team B', _teamBController, Icons.shield_outlined)),
              ],
            ),
            const SizedBox(height: 20),
            _buildField('Venue', _venueController, Icons.location_on_outlined),
            const SizedBox(height: 20),
            _buildField('Overs Per Match', _oversController, Icons.timer_outlined, isNumber: true),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                      );
                      if (date != null) setState(() => _selectedDate = date);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 20, color: Color(0xFF2563EB)),
                          const SizedBox(width: 12),
                          Expanded(child: Text(DateFormat('MMM d, y').format(_selectedDate), style: GoogleFonts.outfit(fontWeight: FontWeight.w600))),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: _selectedTime,
                      );
                      if (time != null) setState(() => _selectedTime = time);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time, size: 20, color: Color(0xFF2563EB)),
                          const SizedBox(width: 12),
                          Expanded(child: Text(_selectedTime.format(context), style: GoogleFonts.outfit(fontWeight: FontWeight.w600))),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, IconData icon, {bool isNumber = false, bool enabled = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.blueAccent, letterSpacing: 1)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: enabled,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          validator: (val) => (val == null || val.isEmpty) && enabled ? 'Required' : null,
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: enabled ? Colors.black : Colors.grey),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 20),
            hintText: !enabled ? 'Auto-generated' : null,
            filled: true,
            fillColor: const Color(0xFFF1F5F9),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1),
    );
  }

  Widget _buildTypeBtn(String type, String label) {
    final active = _competitionType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _competitionType = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF2563EB) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.outfit(
                color: active ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
