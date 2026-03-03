import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';

class FeedbackScreen extends StatefulWidget {
  @override
  _FeedbackScreenState createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  String name = '', email = '', category = 'Web Experience', message = '';
  int rating = 5;
  File? screenshot;
  bool isSubmitting = false;

  final List<String> categories = ['Web Experience', 'Live Scoring Quality', 'Tournament Organization', 'Other'];

  Future<void> _pickImage() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null) {
      setState(() => screenshot = File(result.files.single.path!));
    }
  }

  Future<void> _submitFeedback() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() => isSubmitting = true);

    try {
      final apiUrl = dotenv.env['API_URL'] ?? 'http://10.0.2.2:5000';
      var request = http.MultipartRequest('POST', Uri.parse('$apiUrl/api/interactions/feedback'));
      if (name.isNotEmpty) request.fields['name'] = name;
      if (email.isNotEmpty) request.fields['email'] = email;
      request.fields['rating'] = rating.toString();
      request.fields['feedbackType'] = category;
      request.fields['message'] = message;
      if (screenshot != null) {
        request.files.add(await http.MultipartFile.fromPath('image', screenshot!.path));
      }

      var response = await request.send();
      if (response.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Feedback submitted!'), backgroundColor: Colors.green));
        Navigator.pop(context);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Submission failed.'), backgroundColor: Colors.red));
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
      appBar: AppBar(title: Text('Share Feedback', style: GoogleFonts.inter(fontWeight: FontWeight.bold))),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(5, (index) => IconButton(
                    icon: Icon(index < rating ? Icons.star : Icons.star_border, color: Colors.amber, size: 40),
                    onPressed: () => setState(() => rating = index + 1),
                  )),
                ),
              ),
              SizedBox(height: 24),
              TextFormField(
                decoration: InputDecoration(labelText: 'Name (Optional)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                onSaved: (v) => name = v ?? '',
              ),
              SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(labelText: 'Email (Optional)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                keyboardType: TextInputType.emailAddress,
                onSaved: (v) => email = v ?? '',
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: category,
                decoration: InputDecoration(labelText: 'Category', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => category = v!),
              ),
              SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(labelText: 'Comments *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                maxLines: 4,
                validator: (v) => v!.isEmpty ? 'Comments required' : null,
                onSaved: (v) => message = v!,
              ),
              SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _pickImage,
                icon: Icon(Icons.image),
                label: Text(screenshot == null ? 'Attach Screenshot (Optional)' : 'Image Attached'),
              ),
              SizedBox(height: 32),
              ElevatedButton(
                style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                onPressed: isSubmitting ? null : _submitFeedback,
                child: isSubmitting ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text('SUBMIT FEEDBACK', style: GoogleFonts.inter(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              )
            ],
          ),
        ),
      ),
    );
  }
}
