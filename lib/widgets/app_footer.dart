import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppFooter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final primaryBlue = Color(0xFF2563EB);
    
    return Container(
      padding: EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: primaryBlue.withOpacity(0.02),
        border: Border(top: BorderSide(color: primaryBlue.withOpacity(0.05))),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(2),
                decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: primaryBlue.withOpacity(0.1))),
                child: ClipOval(child: Image.asset('assets/logo.png', height: 30, width: 30)),
              ),
              SizedBox(width: 10),
              Text(
                'SMCC LIVE',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: primaryBlue, fontSize: 16, letterSpacing: 1),
              ),
            ],
          ),
          SizedBox(height: 16),
          Text(
            'S Mettur Cricket Council (SMCC) is dedicated to bringing professional-grade cricket scoring and live updates to our community.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(color: Colors.grey, fontSize: 11, height: 1.5),
          ),
          SizedBox(height: 24),
          Wrap(
            spacing: 20,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              _footerLink('CONTACT'),
              _footerLink('FEEDBACK'),
              _footerLink('REPORT'),
              _footerLink('PRIVACY'),
            ],
          ),
          SizedBox(height: 32),
          Divider(color: primaryBlue.withOpacity(0.05)),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '© 2026 SMCC LIVE',
                style: GoogleFonts.outfit(color: Colors.grey.withOpacity(0.8), fontSize: 9, fontWeight: FontWeight.bold),
              ),
              Text(
                'BY DHANUSH THANGARAJ',
                style: GoogleFonts.outfit(color: primaryBlue.withOpacity(0.8), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _footerLink(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 10, color: Colors.blueGrey, letterSpacing: 1),
    );
  }
}
