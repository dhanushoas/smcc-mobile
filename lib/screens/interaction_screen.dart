import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

class InteractionScreen extends StatefulWidget {
  final String type; // 'contact', 'feedback', 'report'
  final String title;

  InteractionScreen({required this.type, required this.title});

  @override
  _InteractionScreenState createState() => _InteractionScreenState();
}

class _InteractionScreenState extends State<InteractionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  bool isSubmitting = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isSubmitting = true);
    try {
      await ApiService.submitInteraction({
        'type': widget.type,
        'name': _nameController.text,
        'email': _emailController.text,
        'subject': _subjectController.text,
        'message': _messageController.text,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Submitted successfully!'), backgroundColor: Colors.green),
      );
      _formKey.currentState!.reset();
      _nameController.clear();
      _emailController.clear();
      _subjectController.clear();
      _messageController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit. Please try again.'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryBlue = Color(0xFF2563EB);
    
    return Scaffold(
      appBar: AppBar(title: Text(widget.title.toUpperCase())),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            Center(
              child: Column(
                children: [
                  Text(
                    widget.title.toUpperCase(),
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: primaryBlue,
                      letterSpacing: 2,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    _getDescription(),
                    style: GoogleFonts.outfit(color: Colors.grey, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            SizedBox(height: 32),
            if (widget.type == 'contact') _buildContactInfo(),
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
                      _buildLabel('YOUR NAME'),
                      _buildTextField(_nameController, 'John Doe', Icons.person_outline),
                      SizedBox(height: 20),
                      _buildLabel('EMAIL ADDRESS'),
                      _buildTextField(_emailController, 'john@example.com', Icons.email_outlined, isEmail: true),
                      SizedBox(height: 20),
                      _buildLabel('SUBJECT'),
                      _buildTextField(_subjectController, 'Purpose of message', Icons.subject),
                      SizedBox(height: 20),
                      _buildLabel('MESSAGE'),
                      _buildTextField(_messageController, 'Type your message here...', Icons.message_outlined, maxLines: 5),
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
                            elevation: 4,
                          ),
                          child: isSubmitting 
                            ? CircularProgressIndicator(color: Colors.white)
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.send_rounded),
                                  SizedBox(width: 8),
                                  Text('SEND MESSAGE', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
                                ],
                              ),
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

  String _getDescription() {
    switch (widget.type) {
      case 'feedback': return 'Your feedback helps us improve and serve you better.';
      case 'report': return 'Found a bug or issue? Let us know so we can fix it.';
      default: return "Have a question or want to get in touch? We're here to help.";
    }
  }

  Widget _buildContactInfo() {
    return Column(
      children: [
        Row(
          children: [
            _infoCard(Icons.location_on, 'Location', 'Mettur, Salem', Colors.blue),
            SizedBox(width: 12),
            _infoCard(Icons.email, 'Email', 'contact@smcc.org', Colors.green),
          ],
        ),
        SizedBox(height: 24),
      ],
    );
  }

  Widget _infoCard(IconData icon, String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            SizedBox(height: 8),
            Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 10, color: color)),
            Text(value, style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
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

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {bool isEmail = false, int maxLines = 1}) {
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
      validator: (v) {
        if (v == null || v.isEmpty) return 'Required';
        if (isEmail && !v.contains('@')) return 'Invalid email';
        return null;
      },
    );
  }
}
