import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';

class SponsorshipScreen extends StatefulWidget {
  @override
  _SponsorshipScreenState createState() => _SponsorshipScreenState();
}

class _SponsorshipScreenState extends State<SponsorshipScreen> {
  final _formKey = GlobalKey<FormState>();
  String company = '', contactPerson = '', email = '', phone = '', budget = '';
  File? proposal;
  bool isSubmitting = false;
  bool otpSent = false;

  Future<void> _pickDocument() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'ppt', 'pptx']);
    if (result != null) {
      setState(() => proposal = File(result.files.single.path!));
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

  Future<void> _submitPartnership() async {
    if (!_formKey.currentState!.validate()) return;
    if (proposal == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Proposal deck required'), backgroundColor: Colors.red));
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
      var request = http.MultipartRequest('POST', Uri.parse('$apiUrl/api/interactions/sponsorship'));
      request.fields['company'] = company;
      request.fields['contactPerson'] = contactPerson;
      request.fields['email'] = email;
      request.fields['phone'] = phone;
      request.fields['budget'] = budget;
      request.files.add(await http.MultipartFile.fromPath('proposal', proposal!.path));

      var response = await request.send();
      if (response.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Partnership Proposal received successfully!'), backgroundColor: Colors.green));
        Navigator.pop(context);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: Budget must be > 1000.'), backgroundColor: Colors.red));
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
      appBar: AppBar(title: Text('Partner with SMCC', style: GoogleFonts.inter(fontWeight: FontWeight.bold))),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                color: Colors.amber[100],
                elevation: 0,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.business_center, color: Colors.orange[800], size: 30),
                      SizedBox(width: 12),
                      Expanded(child: Text("Accelerate brand growth by partnering with SMCC LIVE ecosystem.", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.orange[900]))),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24),
              TextFormField(
                decoration: InputDecoration(labelText: 'Company / Brand Name *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                validator: (v) => v!.isEmpty ? 'Company name required' : null,
                onSaved: (v) => company = v!,
              ),
              SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(labelText: 'Contact Person *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                validator: (v) => v!.isEmpty ? 'Name required' : null,
                onSaved: (v) => contactPerson = v!,
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: InputDecoration(labelText: 'Official Email *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => v!.isEmpty ? 'Email required' : null,
                      onSaved: (v) => email = v!,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: InputDecoration(labelText: 'Business Phone *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
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
              TextFormField(
                decoration: InputDecoration(labelText: 'Proposed Budget (₹) *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                keyboardType: TextInputType.number,
                validator: (v) => (int.tryParse(v!) ?? 0) < 1000 ? 'Minimum is ₹1,000' : null,
                onSaved: (v) => budget = v!,
              ),
              SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _pickDocument,
                style: OutlinedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 16)),
                icon: Icon(Icons.file_upload),
                label: Text(proposal == null ? 'Attach Proposal Deck (PDF/PPT) *' : 'Deck Attached'),
              ),
              SizedBox(height: 32),
              ElevatedButton(
                style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                onPressed: (isSubmitting || !otpSent) ? null : _submitPartnership,
                child: isSubmitting ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text('SUBMIT PARTNERSHIP PROPOSAL', style: GoogleFonts.inter(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              )
            ],
          ),
        ),
      ),
    );
  }
}
