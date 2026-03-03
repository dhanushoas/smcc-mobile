import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';

class JoinCouncilScreen extends StatefulWidget {
  @override
  _JoinCouncilScreenState createState() => _JoinCouncilScreenState();
}

class _JoinCouncilScreenState extends State<JoinCouncilScreen> {
  final _formKey = GlobalKey<FormState>();
  String name = '', email = '', phone = '', age = '', role = 'Player', experience = '';
  File? idDocument;
  bool isSubmitting = false;
  bool otpSent = false;

  final List<String> roles = ['Player', 'Umpire', 'Scorer', 'Event Organizer'];

  Future<void> _pickDocument() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg']);
    if (result != null) {
      setState(() => idDocument = File(result.files.single.path!));
    }
  }

  void _sendOtp() {
    if (phone.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Enter valid phone first'), backgroundColor: Colors.orange));
      return;
    }
    setState(() => otpSent = true);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('OTP Sent! (Simulation)'), backgroundColor: Colors.green));
  }

  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate()) return;
    if (idDocument == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ID Document required for KYC'), backgroundColor: Colors.red));
      return;
    }
    if (!otpSent) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please verify OTP First'), backgroundColor: Colors.orange));
      return;
    }

    _formKey.currentState!.save();
    setState(() => isSubmitting = true);

    try {
      final apiUrl = dotenv.env['API_URL'] ?? 'http://10.0.2.2:5000';
      var request = http.MultipartRequest('POST', Uri.parse('$apiUrl/api/interactions/join-council'));
      request.fields['name'] = name;
      request.fields['email'] = email;
      request.fields['phone'] = phone;
      request.fields['age'] = age;
      request.fields['role'] = role;
      request.fields['experience'] = experience;
      request.files.add(await http.MultipartFile.fromPath('idDocument', idDocument!.path));

      var response = await request.send();
      if (response.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Application Submitted successfully!'), backgroundColor: Colors.green));
        Navigator.pop(context);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: Under 18 or Invalid data.'), backgroundColor: Colors.red));
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
      appBar: AppBar(title: Text('Join the Council', style: GoogleFonts.inter(fontWeight: FontWeight.bold))),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                color: Colors.blue[50],
                elevation: 0,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.verified_user, color: Colors.blue, size: 30),
                      SizedBox(width: 12),
                      Expanded(child: Text("Identity Verification Required. You must be 18+ to join.", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.blue[800]))),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24),
              TextFormField(
                decoration: InputDecoration(labelText: 'Full Legal Name *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                validator: (v) => v!.isEmpty ? 'Name required' : null,
                onSaved: (v) => name = v!,
              ),
              SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(labelText: 'Email Address *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                keyboardType: TextInputType.emailAddress,
                validator: (v) => v!.isEmpty ? 'Email required' : null,
                onSaved: (v) => email = v!,
              ),
              SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: InputDecoration(labelText: 'Phone Number *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                      keyboardType: TextInputType.phone,
                      validator: (v) => v!.length < 10 ? 'Valid phone required' : null,
                      onChanged: (v) => phone = v,
                      onSaved: (v) => phone = v!,
                    ),
                  ),
                  SizedBox(width: 12),
                  SizedBox(
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: otpSent ? Colors.green : Colors.blue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: _sendOtp,
                      child: Text(otpSent ? 'VERIFIED' : 'GET OTP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: InputDecoration(labelText: 'Age *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                      keyboardType: TextInputType.number,
                      validator: (v) => (int.tryParse(v!) ?? 0) < 18 ? 'Must be 18+' : null,
                      onSaved: (v) => age = v!,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: role,
                      decoration: InputDecoration(labelText: 'Role', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                      items: roles.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (v) => setState(() => role = v!),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _pickDocument,
                style: OutlinedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 16)),
                icon: Icon(Icons.badge),
                label: Text(idDocument == null ? 'Upload ID Document (PDF/JPG) *' : 'ID Attached'),
              ),
              SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(labelText: 'Experience / Background *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                maxLines: 4,
                validator: (v) => v!.isEmpty ? 'Experience required' : null,
                onSaved: (v) => experience = v!,
              ),
              SizedBox(height: 32),
              ElevatedButton(
                style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                onPressed: (isSubmitting || !otpSent) ? null : _submitApplication,
                child: isSubmitting ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text('SUBMIT APPLICATION', style: GoogleFonts.inter(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              )
            ],
          ),
        ),
      ),
    );
  }
}
