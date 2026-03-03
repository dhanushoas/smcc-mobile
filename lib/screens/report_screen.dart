import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

class ReportScreen extends StatefulWidget {
  @override
  _ReportScreenState createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _formKey = GlobalKey<FormState>();
  String type = 'Technical Bug / App Glitch';
  final _matchInfoController = TextEditingController();
  final _messageController = TextEditingController();
  final _evidenceController = TextEditingController();
  bool isSubmitting = false;

  final List<String> types = [
    'Technical Bug / App Glitch',
    'Incorrect Score Entry',
    'Unsportsmanlike Conduct',
    'Umpiring Dispute',
    'Other'
  ];

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isSubmitting = true);
    try {
      await ApiService.submitInteraction({
        'type': 'report',
        'subject': type,
        'message': _messageController.text,
        'data': {
          'matchInfo': _matchInfoController.text,
          'evidence': _evidenceController.text,
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Incident/Issue reported. Our team will investigate immediately.'), backgroundColor: Colors.green),
      );
      _formKey.currentState!.reset();
      _matchInfoController.clear();
      _messageController.clear();
      _evidenceController.clear();
      setState(() {
        type = 'Technical Bug / App Glitch';
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit report.'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('REPORT AN ISSUE')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            Center(
              child: Column(
                children: [
                  Text(
                    'REPORT AN ISSUE',
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.red.shade700,
                      letterSpacing: 2,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Encountered a bug or an incident? Help us maintain the standards of SMCC.',
                    style: GoogleFonts.outfit(color: Colors.grey, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_rounded, color: Colors.orange, size: 32),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Confidential Reporting', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13)),
                        SizedBox(height: 4),
                        Text(
                          'All reports are strictly confidential. We take bugs and misconduct reports very seriously to maintain a healthy sports ecosystem.',
                          style: GoogleFonts.outfit(color: Colors.grey.shade700, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 32),
            Card(
              elevation: 8,
              shadowColor: Colors.black12,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('REPORT TYPE'),
                      DropdownButtonFormField<String>(
                        value: type,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.grey.withOpacity(0.05),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(100), borderSide: BorderSide.none),
                          contentPadding: EdgeInsets.symmetric(horizontal: 24),
                        ),
                        onChanged: (v) => setState(() => type = v!),
                        items: types.map((t) => DropdownMenuItem(value: t, child: Text(t, style: GoogleFonts.outfit(fontSize: 14)))).toList(),
                      ),
                      SizedBox(height: 20),
                      _buildLabel('MATCH DETAILS (IF APPLICABLE)'),
                      _buildTextField(_matchInfoController, 'e.g., Team A vs Team B on Feb 10', Icons.sports_cricket, required: false),
                      SizedBox(height: 20),
                      _buildLabel('DETAILED DESCRIPTION'),
                      _buildTextField(_messageController, 'Explain the issue in detail...', Icons.description, maxLines: 5),
                      SizedBox(height: 20),
                      _buildLabel('ATTACH EVIDENCE (LINK)'),
                      _buildTextField(_evidenceController, 'GDD/Image Link (Optional)', Icons.link, required: false),
                      SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: isSubmitting ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                          ),
                          child: isSubmitting 
                            ? CircularProgressIndicator(color: Colors.white)
                            : Text('SUBMIT INCIDENT REPORT', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8),
      child: Text(text, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey)),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {int maxLines = 1, bool required = true}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: GoogleFonts.outfit(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Padding(
          padding: EdgeInsets.only(bottom: maxLines > 1 ? 75 : 0),
          child: Icon(icon, size: 20),
        ),
        filled: true,
        fillColor: Colors.grey.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(maxLines > 1 ? 20 : 100), borderSide: BorderSide.none),
        contentPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      ),
      validator: required ? ((v) => (v == null || v.isEmpty) ? 'Required' : null) : null,
    );
  }
}
