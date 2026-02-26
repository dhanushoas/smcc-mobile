import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

class ImprovementsScreen extends StatefulWidget {
  @override
  _ImprovementsScreenState createState() => _ImprovementsScreenState();
}

class _ImprovementsScreenState extends State<ImprovementsScreen> {
  final _formKey = GlobalKey<FormState>();
  String category = 'Live Scoring Experience';
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool isSubmitting = false;

  final List<String> categories = [
    'Live Scoring Experience',
    'Admin Dashboard Tools',
    'Member Portal Features',
    'Mobile Performance',
    'Other'
  ];

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isSubmitting = true);
    try {
      await ApiService.submitInteraction({
        'type': 'improvement',
        'subject': _titleController.text,
        'message': _descriptionController.text,
        'data': {'category': category}
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Thank you! Your idea has been submitted.'), backgroundColor: Colors.green),
      );
      _formKey.currentState!.reset();
      _titleController.clear();
      _descriptionController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit suggestion.'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryBlue = Color(0xFF2563EB);
    
    return Scaffold(
      appBar: AppBar(title: Text('IMPROVEMENTS')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            Center(
              child: Column(
                children: [
                  Text(
                    'PLATFORM IMPROVEMENTS',
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: primaryBlue,
                      letterSpacing: 1,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Have an idea to make SMCC LIVE better? We're all ears.",
                    style: GoogleFonts.outfit(color: Colors.grey, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildIdeaIcon(Icons.bolt, 'Features', Colors.orange),
                _buildIdeaIcon(Icons.brush, 'UI/UX', Colors.blue),
                _buildIdeaIcon(Icons.trending_up, 'Stats', Colors.green),
              ],
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
                      _buildLabel('IDEA CATEGORY'),
                      DropdownButtonFormField<String>(
                        value: category,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.grey.withOpacity(0.05),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(100), borderSide: BorderSide.none),
                          contentPadding: EdgeInsets.symmetric(horizontal: 24),
                        ),
                        onChanged: (v) => setState(() => category = v!),
                        items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: GoogleFonts.outfit(fontSize: 14)))).toList(),
                      ),
                      SizedBox(height: 20),
                      _buildLabel('TITLE OF YOUR SUGGESTION'),
                      _buildTextField(_titleController, 'Short descriptive title', Icons.title),
                      SizedBox(height: 20),
                      _buildLabel('THE VISION'),
                      _buildTextField(_descriptionController, 'Describe your idea and how it would benefit the community...', Icons.lightbulb_outline, maxLines: 6),
                      SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: isSubmitting ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                          ),
                          child: isSubmitting 
                            ? CircularProgressIndicator(color: Colors.white)
                            : Text('SUBMIT SUGGESTION', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13)),
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

  Widget _buildIdeaIcon(IconData icon, String text, Color color) {
    return Column(
      children: [
        Icon(icon, size: 32, color: color),
        SizedBox(height: 4),
        Text(text.toUpperCase(), style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey)),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8),
      child: Text(text, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey)),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: GoogleFonts.outfit(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: Colors.grey.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(maxLines > 1 ? 20 : 100), borderSide: BorderSide.none),
        contentPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      ),
      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
    );
  }
}
