// Feedback screen for SMCC platform
// Lets users rate their experience and submit category-based feedback
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

class FeedbackScreen extends StatefulWidget {
  @override
  _FeedbackScreenState createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  int rating = 5;
  final _nameController = TextEditingController();
  final _messageController = TextEditingController();
  String category = 'Web Experience';
  bool isSubmitting = false;

  final List<String> categories = [
    'Web Experience',
    'Live Scoring Quality',
    'Tournament Organization',
    'Other'
  ];

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isSubmitting = true);
    try {
      await ApiService.submitInteraction({
        'type': 'feedback',
        'name': _nameController.text,
        'message': _messageController.text,
        'data': {'rating': rating, 'category': category}
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Thank you for your valuable feedback!'), backgroundColor: Colors.green),
      );
      _formKey.currentState!.reset();
      _nameController.clear();
      _messageController.clear();
      setState(() {
        rating = 5;
        category = 'Web Experience';
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit feedback.'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryBlue = Color(0xFF2563EB);
    
    return Scaffold(
      appBar: AppBar(title: Text('SHARE FEEDBACK')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            Center(
              child: Column(
                children: [
                  Text(
                    'SHARE FEEDBACK',
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: primaryBlue,
                      letterSpacing: 2,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Your feedback helps us provide a better experience for everyone.',
                    style: GoogleFonts.outfit(color: Colors.grey, fontSize: 11),
                    textAlign: TextAlign.center,
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
                      Center(
                        child: Column(
                          children: [
                            Text(
                              'HOW WAS YOUR EXPERIENCE?',
                              style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1),
                            ),
                            SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(5, (index) {
                                final starVal = index + 1;
                                return GestureDetector(
                                  onTap: () => setState(() => rating = starVal),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                    child: Icon(
                                      starVal <= rating ? Icons.star : Icons.star_border,
                                      color: starVal <= rating ? Colors.amber : Colors.grey.shade300,
                                      size: 40,
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 32),
                      _buildLabel('NAME'),
                      _buildTextField(_nameController, 'Your Name', Icons.person),
                      SizedBox(height: 20),
                      _buildLabel('CATEGORY'),
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
                      _buildLabel('COMMENTS'),
                      _buildTextField(_messageController, 'Tell us what you loved or what we can improve...', Icons.message, maxLines: 4),
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
                            : Text('SUBMIT FEEDBACK', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13)),
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

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: GoogleFonts.outfit(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Padding(
          padding: EdgeInsets.only(bottom: maxLines > 1 ? 55 : 0),
          child: Icon(icon, size: 20),
        ),
        filled: true,
        fillColor: Colors.grey.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(maxLines > 1 ? 20 : 100), borderSide: BorderSide.none),
        contentPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      ),
      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
    );
  }
}
