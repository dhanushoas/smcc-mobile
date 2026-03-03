import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';

class ImprovementsScreen extends StatefulWidget {
  @override
  _ImprovementsScreenState createState() => _ImprovementsScreenState();
}

class _ImprovementsScreenState extends State<ImprovementsScreen> {
  final _formKey = GlobalKey<FormState>();
  String name = '', email = '', category = 'Live Scoring Experience', priority = 'Low', title = '', message = '';
  bool isSubmitting = false;

  final List<String> categories = ['Live Scoring Experience', 'Admin Dashboard Tools', 'Member Portal Features', 'Mobile Performance', 'Other'];
  final List<String> priorities = ['Low', 'Medium', 'High'];

  Future<void> _submitIdea() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() => isSubmitting = true);

    try {
      final apiUrl = dotenv.env['API_URL'] ?? 'http://10.0.2.2:5000';
      var request = http.MultipartRequest('POST', Uri.parse('$apiUrl/api/interactions/improvement'));
      if (name.isNotEmpty) request.fields['name'] = name;
      if (email.isNotEmpty) request.fields['email'] = email;
      request.fields['category'] = category;
      request.fields['priority'] = priority;
      request.fields['title'] = title;
      request.fields['description'] = message;

      var response = await request.send();
      if (response.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Suggestion submitted. Thanks!'), backgroundColor: Colors.green));
        Navigator.pop(context);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invalid input or Duplicate entry (7-day block).'), backgroundColor: Colors.red));
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
      appBar: AppBar(title: Text('Platform Improvements', style: GoogleFonts.inter(fontWeight: FontWeight.bold))),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                color: Colors.blue.withOpacity(0.1),
                elevation: 0,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb, color: Colors.blue, size: 30),
                      SizedBox(width: 12),
                      Expanded(child: Text("Have an idea to make SMCC LIVE better? We're all ears.", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.blue[800]))),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24),
              TextFormField(
                decoration: InputDecoration(labelText: 'Idea Title *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                validator: (v) => v!.length < 5 ? 'Title too short (>5 chars)' : null,
                onSaved: (v) => title = v!,
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: category,
                decoration: InputDecoration(labelText: 'Category', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => category = v!),
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: priority,
                decoration: InputDecoration(labelText: 'Priority', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                items: priorities.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => priority = v!),
              ),
              SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(labelText: 'The Vision (Details) *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                maxLines: 5,
                validator: (v) => v!.length < 20 ? 'Please describe your idea in detail (>20 chars)' : null,
                onSaved: (v) => message = v!,
              ),
              SizedBox(height: 32),
              ElevatedButton(
                style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                onPressed: isSubmitting ? null : _submitIdea,
                child: isSubmitting ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text('SUBMIT SUGGESTION', style: GoogleFonts.inter(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              )
            ],
          ),
        ),
      ),
    );
  }
}
