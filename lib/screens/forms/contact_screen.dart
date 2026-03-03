import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';

class ContactScreen extends StatefulWidget {
  @override
  _ContactScreenState createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final _formKey = GlobalKey<FormState>();
  String name = '', email = '', phone = '', subject = '', message = '';
  bool isSubmitting = false;

  Future<void> _submitRecord() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() => isSubmitting = true);

    try {
      final apiUrl = dotenv.env['API_URL'] ?? 'http://10.0.2.2:5000';
      var request = http.MultipartRequest('POST', Uri.parse('$apiUrl/api/interactions/contact'));
      request.fields['name'] = name;
      request.fields['email'] = email;
      if (phone.isNotEmpty) request.fields['phone'] = phone;
      if (subject.isNotEmpty) request.fields['subject'] = subject;
      request.fields['message'] = message;

      var response = await request.send();
      if (response.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Message sent successfully!'), backgroundColor: Colors.green));
        Navigator.pop(context);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send message: ${response.statusCode}'), backgroundColor: Colors.red));
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
      appBar: AppBar(title: Text('Contact Us', style: GoogleFonts.inter(fontWeight: FontWeight.bold))),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                decoration: InputDecoration(labelText: 'Full Name *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                validator: (v) => v!.isEmpty ? 'Name required' : null,
                onSaved: (v) => name = v!,
              ),
              SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(labelText: 'Email Address *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                keyboardType: TextInputType.emailAddress,
                validator: (v) => v!.isEmpty || !v.contains('@') ? 'Valid email required' : null,
                onSaved: (v) => email = v!,
              ),
              SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(labelText: 'Phone Number (Optional)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                keyboardType: TextInputType.phone,
                onSaved: (v) => phone = v ?? '',
              ),
              SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(labelText: 'Subject (Optional)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                onSaved: (v) => subject = v ?? '',
              ),
              SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(labelText: 'Message *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                maxLines: 5,
                validator: (v) => v!.isEmpty ? 'Message required' : null,
                onSaved: (v) => message = v!,
              ),
              SizedBox(height: 32),
              ElevatedButton(
                style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                onPressed: isSubmitting ? null : _submitRecord,
                child: isSubmitting ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text('SEND MESSAGE', style: GoogleFonts.inter(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              )
            ],
          ),
        ),
      ),
    );
  }
}
