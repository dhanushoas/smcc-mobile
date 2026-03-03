import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';

class ReportScreen extends StatefulWidget {
  @override
  _ReportScreenState createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _formKey = GlobalKey<FormState>();
  String name = '', email = '', issueType = 'Technical Bug / App Glitch', severity = 'Medium', matchInfo = '', description = '';
  File? screenshot;
  bool isSubmitting = false;

  final List<String> issueTypes = ['Technical Bug / App Glitch', 'Incorrect Score Entry', 'Unsportsmanlike Conduct', 'Umpiring Dispute', 'Other'];
  final List<String> severities = ['Low', 'Medium', 'High'];

  Future<void> _pickImage() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['png', 'jpg', 'jpeg', 'pdf']);
    if (result != null) {
      setState(() => screenshot = File(result.files.single.path!));
    }
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() => isSubmitting = true);

    try {
      final apiUrl = dotenv.env['API_URL'] ?? 'http://10.0.2.2:5000';
      var request = http.MultipartRequest('POST', Uri.parse('$apiUrl/api/interactions/report'));
      if (name.isNotEmpty) request.fields['name'] = name;
      if (email.isNotEmpty) request.fields['email'] = email;
      request.fields['issueType'] = issueType;
      request.fields['severity'] = severity;
      request.fields['description'] = matchInfo.isNotEmpty ? "Match: $matchInfo - $description" : description;
      request.fields['pageUrl'] = "Mobile App Form";
      if (screenshot != null) {
        request.files.add(await http.MultipartFile.fromPath('screenshot', screenshot!.path));
      }

      var response = await request.send();
      if (response.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Incident reported securely.'), backgroundColor: Colors.green));
        Navigator.pop(context);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed submission. Check inputs.'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Network error.'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Report Issue', style: GoogleFonts.inter(fontWeight: FontWeight.bold))),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(child: Text('All reports are confidential.', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange[800]))),
                  ],
                ),
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: issueType,
                decoration: InputDecoration(labelText: 'Report Type', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                items: issueTypes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => issueType = v!),
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: severity,
                decoration: InputDecoration(labelText: 'Severity', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                items: severities.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => severity = v!),
              ),
              SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(labelText: 'Match Details (Optional)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                onSaved: (v) => matchInfo = v ?? '',
              ),
              SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(labelText: 'Detailed Description *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                maxLines: 4,
                validator: (v) => v!.isEmpty ? 'Description required' : null,
                onSaved: (v) => description = v!,
              ),
              SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _pickImage,
                icon: Icon(Icons.attach_file),
                label: Text(screenshot == null ? 'Attach Evidence (Image/PDF)' : 'Evidence Attached'),
              ),
              SizedBox(height: 32),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                onPressed: isSubmitting ? null : _submitReport,
                child: isSubmitting ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text('SUBMIT INCIDENT', style: GoogleFonts.inter(fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.white)),
              )
            ],
          ),
        ),
      ),
    );
  }
}
